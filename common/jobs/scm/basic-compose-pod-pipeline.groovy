node {
  stage('checkout') {
    gitBranch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_branch?raw").trim()
    gitURL = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_url?raw").trim()
    checkout_info = checkout([$class: 'GitSCM',
      branches: [[name: gitBranch]],
      doGenerateSubmoduleConfigurations: false,
      submoduleCfg: [],
      userRemoteConfigs: [[url: gitURL]]])
    sh("curl -Ssf -X PUT -d ${checkout_info.GIT_COMMIT} http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_commit_id >/dev/null")
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
      BUILD_DIR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_dir?raw)"
      cd "${WORKSPACE}/${BUILD_DIR}"
      ansible all -i localhost, --connection=local -m template -a "src=nomad-job.hcl.j2 dest=nomad-job.hcl" >/dev/null
      nomad validate nomad-job.hcl
      trap 'docker-compose --project-name "${POD_NAME}-${POD_TAG}" down -v --rmi all --remove-orphans' EXIT
      docker-compose --project-name "${POD_NAME}-${POD_TAG}" --no-ansi build --no-cache
      docker-compose --project-name "${POD_NAME}-${POD_TAG}" --no-ansi push
      '''
    }
  }
  stage('deploy') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    SSH_DEPLOY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/${PLATFORM_ENVIRONMENT}/ssh_deploy_address?raw)"
    trap 'ssh -S "${WORKSPACE}/ssh-control-socket" -O exit ${SSH_DEPLOY_ADDRESS}' EXIT
    SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ExitOnForwardFailure=yes'
    CHECKOUT_COMMIT_ID="$(curl -Ssf http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_commit_id?raw)"
    POD_TAG="${CHECKOUT_COMMIT_ID:0:7}"
    tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
    ssh ${SSH_OPTS} -f -N -M -S "${WORKSPACE}/ssh-control-socket" -L ${tunnel_port}:127.0.0.1:4646 ${SSH_DEPLOY_ADDRESS}
    BUILD_DIR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_dir?raw)"
    cd "${WORKSPACE}/${BUILD_DIR}"
    nomad run -output nomad-job.hcl > nomad-job.json
    NOMAD_ADDR=http://127.0.0.1:${tunnel_port}
    EVAL_ID="$(curl -Ssf -X POST -d @nomad-job.json ${NOMAD_ADDR}/v1/jobs | jq -re .[EvalID])"
    
    curl -Ssf -X PUT -d "${POD_TAG}" ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/tag_version >/dev/null
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}