node {
  stage('checkout') {
    checkout([$class: 'GitSCM', 
      branches: [[name: '*/master']], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
  }
  stage('update') {
    sh './apl-wrapper.sh ansible/os-update.yml'
  }
  stage('cleanup') {
    cleanWs()
  }
}
