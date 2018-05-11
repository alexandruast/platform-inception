node {
  stage('validate') {
    sh '''
      [ x"${ANSIBLE_TARGET}" != 'x' ]
      [ x"${ANSIBLE_SCOPE}" != 'x' ]
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
        if [[ *"@"* == "${ANSIBLE_TARGET}" ]]; then
          SSH_TARGET="${ANSIBLE_TARGET}"
        else
          SSH_USER=$(echo "${ANSIBLE_EXTRAVARS}" | tr "'" '"' | jq -r .ansible_user)
          if [[ "${SSH_USER}" != "" ]]; then
            SSH_TARGET="${SSH_USER}@${ANSIBLE_TARGET}"
          else
            SSH_TARGET="${ANSIBLE_TARGET}"
          fi
        fi
        # echo "SSH_TARGET=${SSH_TARGET}" >> .jenkins_env
        curl -Ss --request PUT --data "${SSH_TARGET}" http://127.0.0.1:8500/v1/kv/jenkins/pipeline_nomad_deploy_ssh_target
      '''
  }
  stage('provision') {
    sh '''#!/usr/bin/env bash
      set -xeEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      SSH_TARGET="$(curl -Ss http://127.0.0.1:8500/v1/kv/jenkins/pipeline_nomad_deploy_ssh_target?raw)"
      SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'
      ssh ${SSH_OPTS} ${SSH_TARGET} "sudo yum -q -y install python libselinux-python"
      ./apl-wrapper.sh ansible/target-nomad-${ANSIBLE_SCOPE}.yml
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
