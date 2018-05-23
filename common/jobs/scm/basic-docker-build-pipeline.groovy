node {
  stage('checkout') {
    gitBranch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_branch?raw").trim()
    gitURL = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_url?raw").trim()
    checkout_info = checkout([$class: 'GitSCM',
      branches: [[name: gitBranch]],
      doGenerateSubmoduleConfigurations: false,
      submoduleCfg: [],
      userRemoteConfigs: [[url: gitURL]]])
    sh("curl -Ssf -X PUT -d ${checkout_info.GIT_COMMIT} http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_commit_id")
  }
  stage('test') {
    sh '''
      cd "${WORKSPACE}/$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_dir?raw)"
      ./run-tests.sh
      '''
  }
  stage('build') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      sh '''#!/usr/bin/env bash
      set -xeuEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      CHECKOUT_COMMIT_ID="$(curl -Ssf http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_commit_id?raw)"
      POD_TAG="${CHECKOUT_COMMIT_ID:0:7}"
      VAULT_ADDR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/vault_address?raw)"
      REGISTRY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/docker_registry_address?raw)"
      REGISTRY_PATH="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/docker_registry_path?raw)"
      REGISTRY_CREDENTIALS="$(curl -Ssf -X GET \
        -H "X-Vault-Token:${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/operations/docker-registry" | jq -re .data.value)"
      REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
      REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"
      export REGISTRY_ADDRESS
      export REGISTRY_USERNAME
      export REGISTRY_PASSWORD
      export REGISTRY_PATH
      export POD_NAME
      export POD_TAG
      docker login "${REGISTRY_ADDRESS}" --username="${REGISTRY_USERNAME}" --password-stdin <<< ${REGISTRY_PASSWORD} >/dev/null
      cd "${WORKSPACE}/$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_dir?raw)"
      docker build -t ${REGISTRY_ADDRESS}/${REGISTRY_PATH}/${POD_NAME}:${POD_TAG} ./
      docker push ${REGISTRY_ADDRESS}/${REGISTRY_PATH}/${POD_NAME}:${POD_TAG}
      curl -Ssf -X PUT -d "${POD_TAG}" ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/tag_version
      '''
    }
  }
  stage('cleanup') {
    cleanWs()
  }
}