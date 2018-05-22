node {
  stage('checkout') {
    checkout_info = checkout([$class: 'GitSCM', 
      branches: [[name: "${APPLICATION_BRANCH}"]], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: "${APPLICATION_SCM}"]]])
    sh("curl -Ssf -X PUT -d ${checkout_info.GIT_COMMIT} http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${APPLICATION_NAME}/checkout_commit_id")
  }
  stage('build') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      sh '''#!/usr/bin/env bash
      set -xeuEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      trap 'docker-compose down' EXIT
      CHECKOUT_COMMIT_ID="$(curl -Ssf http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${APPLICATION_NAME}/checkout_commit_id?raw)"
      APPLICATION_TAG="${CHECKOUT_COMMIT_ID:0:7}"
      VAULT_ADDR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/vault_address?raw)"
      REGISTRY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/docker_registry_address?raw)"
      REGISTRY_PATH="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/docker_registry_path?raw)"
      REGISTRY_CREDENTIALS="$(curl -Ssf -X GET \
        -H "X-Vault-Token:${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/operations/docker-registry" | jq -re .data.value)"
      REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
      REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"
      export REGISTRY_ADDRESS
      export REGISTRY_USERNAME
      export REGISTRY_PASSWORD
      export REGISTRY_PATH
      export APPLICATION_NAME
      export APPLICATION_TAG
      docker login "${REGISTRY_ADDRESS}" --username="${REGISTRY_USERNAME}" --password-stdin <<< ${REGISTRY_PASSWORD} >/dev/null
      '''
    }
  }
  stage('cleanup') {
    cleanWs()
  }
}