node {
  stage('checkout') {
    checkout_info = checkout([$class: 'GitSCM', 
      branches: [[name: "${POD_BRANCH}"]], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: "${POD_SCM}"]]])
    sh("curl -Ssf --request PUT --data ${checkout_info.GIT_COMMIT} http://127.0.0.1:8500/v1/kv/${POD_ENVIRONMENT}/${POD_NAME}/checkout_commit_id")
  }
  stage('build') {
    withCredentials([string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN')]) {
      sh '''#!/usr/bin/env bash
      set -xeuEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      trap 'docker-compose down' EXIT
      CHECKOUT_COMMIT_ID="$(curl -Ssf http://127.0.0.1:8500/v1/kv/${POD_ENVIRONMENT}/${POD_NAME}/checkout_commit_id?raw)"
      POD_TAG="${CHECKOUT_COMMIT_ID:0:7}"
      REGISTRY_CREDENTIALS="$(curl -Ssf -X GET \
        -H "X-Vault-Token:${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/operations/docker-registry" | jq -re .data.value)"
      REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
      REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"
      REGISTRY_ADDRESS="docker.io"
      REPOSITORY_NAME="platformdemo"
      export REGISTRY_ADDRESS
      export REGISTRY_USERNAME
      export REGISTRY_PASSWORD
      export REPOSITORY_NAME
      export POD_NAME
      export POD_TAG
      docker login "${REGISTRY_ADDRESS}" --username="${REGISTRY_USERNAME}" --password-stdin <<< ${REGISTRY_PASSWORD} >/dev/null
      cd "${WORKSPACE}/pods/${POD_NAME}" || ls -1 docker-compose.yml
      ansible all -i localhost, --connection=local -m template -a "src=nomad-job.hcl.j2 dest=nomad-job.hcl" >/dev/null
      nomad validate nomad-job.hcl
      docker-compose --no-ansi build
      docker-compose --no-ansi push
      '''
    }
  }
  stage('deploy') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    trap 'ssh -S "${WORKSPACE}/ssh-control-socket" -O exit vagrant@192.168.169.181' EXIT
    SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ExitOnForwardFailure=yes'
    tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
    ssh ${SSH_OPTS} -f -N -M -S "${WORKSPACE}/ssh-control-socket" -L ${tunnel_port}:127.0.0.1:4646 vagrant@192.168.169.181
    cd "${WORKSPACE}/pods/${POD_NAME}" || ls -1 docker-compose.yml
    NOMAD_ADDR=http://127.0.0.1:${tunnel_port} nomad run nomad-job.hcl
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}