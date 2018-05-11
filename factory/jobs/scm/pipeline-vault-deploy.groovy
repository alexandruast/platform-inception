node {
  stage('validate') {
    sh '''
      [ x"${ANSIBLE_TARGET}" != 'x' ]
      echo "ANSIBLE_EXTRAVARS=${ANSIBLE_EXTRAVARS}"
    '''
  }
  stage('prepare') {
    checkout([$class: 'GitSCM', 
      branches: [[name: '*/devel']], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
      sh '''
        declare -a SSH_TARGETS
        for s in ${ANSIBLE_TARGET//,/ }; do
          if [[ *"@"* == "${s}" ]]; then
            SSH_TARGETS=("${SSH_TARGETS}" "${s}")
          else
            SSH_USER=$(echo "${ANSIBLE_EXTRAVARS}" | tr "'" '"' | jq -r .ansible_user)
            if [[ "${SSH_USER}" != "" ]]; then
              SSH_TARGETS=("${SSH_TARGETS}" "${SSH_USER}@${s}")
            else
              SSH_TARGETS=("${SSH_TARGETS}" "${s}")
            fi
          fi
        done
        curl -Ss --request PUT --data "$(IFS=$','; echo "${SSH_TARGETS[*]}")" http://127.0.0.1:8500/v1/kv/jenkins/pipeline_vault_deploy_ssh_targets
      '''
  }
  stage('provision') {
    sh '''#!/usr/bin/env bash
      set -xeEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      SSH_TARGETS="$(curl -Ss http://127.0.0.1:8500/v1/kv/jenkins/pipeline_vault_deploy_ssh_targets?raw)"
      SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'
      for s in ${SSH_TARGETS//,/ }; do
        ssh ${SSH_OPTS} ${s} "sudo yum -q -y install python libselinux-python"
      done
      ./apl-wrapper.sh ansible/target-vault-server.yml
    '''
  }
  stage('deploy') {
    sh '''#!/usr/bin/env bash
      set -xeEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}
