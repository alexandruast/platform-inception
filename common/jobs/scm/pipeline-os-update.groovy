node {
  stage('validation') {
    sh '''
      [ x"${ANSIBLE_TARGET}" != 'x' ]
      echo "ANSIBLE_EXTRAVARS=${ANSIBLE_EXTRAVARS}"
      ansible --version
    '''
  }
  stage('preparation') {
    checkout([$class: 'GitSCM', 
      branches: [[name: '*/devel']], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
  }
  stage('update') {
    sh '''
      ./apl-wrapper.sh ansible/os-update.yml
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}
