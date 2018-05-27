node {
  stage('checkout') {
    scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_branch?raw").trim()
    scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_url?raw").trim()
    checkout_info = checkout([$class: 'GitSCM',
      branches: [[name: scm_branch]],
      doGenerateSubmoduleConfigurations: false,
      submoduleCfg: [],
      userRemoteConfigs: [[url: scm_url]]])
  }
  stage('build') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      sh '''
      # extras/compose-pod-build.sh
      curl -LSs https://raw.githubusercontent.com/alexandruast/platform-inception/devel/extras/compose-pod-build.sh > ./compose-pod-build.sh
      chmod +x ./compose-pod-build.sh
      ./compose-pod-build.sh
      '''
    }
  }
  stage('deploy') {
    sh '''
      # extras/compose-pod-deploy.sh
      curl -LSs https://raw.githubusercontent.com/alexandruast/platform-inception/devel/extras/compose-pod-deploy.sh > ./compose-pod-deploy.sh
      chmod +x ./compose-pod-deploy.sh
      ./compose-pod-deploy.sh
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}