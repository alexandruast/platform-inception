node {
  stage('validation') {
    sh '''
      [ x"${POD_NAME}" != 'x' ]
      [ x"${POD_ENVIRONMENT}" != 'x' ]
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
    export REGISTRY_ADDRESS
    export REGISTRY_USERNAME
    export REGISTRY_PASSWORD
    export REPOSITORY_NAME
    export POD_VERSION
    export POD_NAME
    docker system prune -f
    docker volume prune -f
    ANSIBLE_TARGET=127.0.0.1 \
      ANSIBLE_EXTRAVARS="{'pwd':'$(pwd)'}" \
      ./apl-wrapper.sh ansible/nomad-job.yml
    cd "./pods/${POD_NAME}"
    nomad validate nomad-job.hcl
    docker-compose --no-ansi build --no-cache
    docker-compose --no-ansi push
    '''
  }
  stage('run-tests') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
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
    NOMAD_ADDR=http://127.0.0.1:${tunnel_port} nomad run "./pods/${POD_NAME}/nomad-job.hcl"
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}