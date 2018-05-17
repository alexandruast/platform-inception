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
    trap 'docker-compose down --rmi all --volumes' EXIT
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
    docker system prune -f
    docker volume prune -f
    docker-compose --no-ansi build --no-cache
    docker-compose --no-ansi push
    '''
  }
  stage('deploy-pod') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    trap 'ssh -S ssh-control-socket -O exit vagrant@192.168.169.181' EXIT
    SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ExitOnForwardFailure=yes'
    tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
    ssh ${SSH_OPTS} -f -N -M -S ssh-control-socket -L ${tunnel_port}:127.0.0.1:4646 vagrant@192.168.169.181
    NOMAD_ADDR=http://127.0.0.1:${tunnel_port} nomad status
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}