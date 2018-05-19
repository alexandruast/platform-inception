node {
  stage('checkout') {
    checkout_info = checkout([$class: 'GitSCM', 
      branches: [[name: '*/devel']], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
    sh("curl -Ssf --request PUT --data ${checkout_info.COMMIT_ID.substring(0,6)} http://127.0.0.1:8500/v1/kv/${POD_NAME}/checkout_commit_id")
  }
  stage('build') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    trap 'docker-compose down --rmi all --volumes' EXIT
    checkout_commit_id="$(curl -Ssf http://127.0.0.1:8500/v1/kv/${POD_NAME}/checkout_commit_id?raw)"
    build_commit_id="$(curl -Ssf http://127.0.0.1:8500/v1/kv/${POD_NAME}/build_commit_id?raw)"
    POD_VERSION="${checkout_commit_id}"
    REGISTRY_CREDENTIALS="platformdemo:63hu8y1L7X3BBel8"
    REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
    REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"
    REGISTRY_ADDRESS="docker.io"
    REPOSITORY_NAME="platformdemo"
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
    ANSIBLE_TARGET=127.0.0.1 \
      ANSIBLE_EXTRAVARS="{'pwd':'$(pwd)'}" \
      ./apl-wrapper.sh ansible/nomad-job.yml
    cd "./pods/${POD_NAME}"
    nomad validate nomad-job.hcl
    if [[ "${checkout_commit_id}" != "${build_commit_id}" ]]; then
      docker-compose --no-ansi build --no-cache
      docker-compose --no-ansi push
      sh("curl -Ssf --request PUT --data ${checkout_commit_id} http://127.0.0.1:8500/v1/kv/${POD_NAME}/build_commit_id")
    fi
    '''
  }
  stage('deploy') {
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