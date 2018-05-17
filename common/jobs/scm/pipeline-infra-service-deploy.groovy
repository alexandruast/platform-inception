node {
  stage('validation') {
    sh '''
      [ x"${SERVICE_NAME}" != 'x' ]
      [ x"${SERVICE_ENVIRONMENT}" != 'x' ]
      [ x"${SERVICE_VERSION}" != 'x' ]
      echo "ANSIBLE_EXTRAVARS=${ANSIBLE_EXTRAVARS}"
      ansible --version
      docker --version
      docker-compose --version
    '''
  }
  stage('preparation') {
    checkout([$class: 'GitSCM', 
      branches: [[name: '*/devel']], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
  }
  stage('build-image') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    CONSUL_ADDR="${CONSUL_ADDR:-http://127.0.0.1:8500}"
    VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
    DOCKER_REGISTRY_CREDENTIALS="platformdemo:63hu8y1L7X3BBel8"
    DOCKER_REGISTRY_USERNAME="${DOCKER_REGISTRY_CREDENTIALS%:*}"
    DOCKER_REGISTRY_PASSWORD="${DOCKER_REGISTRY_CREDENTIALS#*:}"
    export DOCKER_REGISTRY_ADDRESS="docker.io"
    export DOCKER_REPOSITORY_NAME="platformdemo"
    export DOCKER_SERVICE_NAME="${SERVICE_NAME}"
    export DOCKER_SERVICE_VERSION="$(date "+%Y%m%d%H%M%S")"
    echo "[info] ${DOCKER_REGISTRY_ADDRESS} docker registry login..."
    docker login "${DOCKER_REGISTRY_ADDRESS}" \
      --username="${DOCKER_REGISTRY_USERNAME}" \
      --password-stdin <<< ${DOCKER_REGISTRY_PASSWORD} >/dev/null
    cd "./services/${SERVICE_NAME}"
    docker-compose --no-ansi build
    docker-compose --no-ansi push
    '''
  }
  stage('deploy-service') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}