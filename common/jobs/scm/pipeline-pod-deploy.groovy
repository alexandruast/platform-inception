node {
  stage('validation') {
    sh '''
      [ x"${POD_NAME}" != 'x' ]
      [ x"${POD_ENVIRONMENT}" != 'x' ]
      echo "ANSIBLE_EXTRAVARS=${ANSIBLE_EXTRAVARS}"
      ansible --version
      docker --version
      docker-compose --version
      nomad --version
    '''
  }
  stage('preparation') {
    checkout([$class: 'GitSCM', 
      branches: [[name: '*/devel']], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
  }
  stage('build-images') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    CONSUL_ADDR="${CONSUL_ADDR:-http://127.0.0.1:8500}"
    VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
    REGISTRY_CREDENTIALS="platformdemo:63hu8y1L7X3BBel8"
    REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
    REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"
    REGISTRY_ADDRESS="docker.io"
    REPOSITORY_NAME="platformdemo"
    POD_VERSION="$(date "+%Y%m%d%H%M%S")"
    echo "[info] ${REGISTRY_ADDRESS} docker registry login..."
    docker login "${REGISTRY_ADDRESS}" \
      --username="${REGISTRY_USERNAME}" \
      --password-stdin <<< ${REGISTRY_PASSWORD} >/dev/null
    cd "./pods/${POD_NAME}"
    export REGISTRY_ADDRESS
    export REPOSITORY_NAME
    export POD_VERSION
    docker-compose --no-ansi build
    docker-compose --no-ansi push
    echo ""
    '''
  }
  stage('deploy-job') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}