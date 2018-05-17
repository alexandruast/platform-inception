node {
  stage('validation') {
    sh '''
      [ x"${SERVICE_NAME}" != 'x' ]
      [ x"${SERVICE_ENVIRONMENT}" != 'x' ]
      [ x"${SERVICE_VERSION}" != 'x' ]
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
      echo "Test"
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}