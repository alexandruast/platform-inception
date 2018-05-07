node {
  stage('validate') {
    sh '''
      [ x"${ANSIBLE_TARGET}" != 'x' ]
      [ x"${ANSIBLE_SCOPE}" != 'x' ]
      [ x"${ANSIBLE_EXTRAVARS}" != 'x' ]
    '''
  }
  stage('prepare') {
    checkout([$class: 'GitSCM', 
      branches: [[name: '*/devel']], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
  }
  stage('provision') {
    sh '''#!/usr/bin/env bash
      set -xeEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
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
