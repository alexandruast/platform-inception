node {
  stage('checkout') {
    gitBranch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_branch?raw").trim()
    gitURL = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_url?raw").trim()
    checkout_info = checkout([$class: 'GitSCM',
      branches: [[name: gitBranch]],
      doGenerateSubmoduleConfigurations: false,
      submoduleCfg: [],
      userRemoteConfigs: [[url: gitURL]]])
  }
  stage('build') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      gitBranch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/scm_branch?raw").trim()
      gitURL = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/scm_url?raw").trim()
      checkout_info = checkout([$class: 'GitSCM',
        branches: [[name: gitBranch]],
        doGenerateSubmoduleConfigurations: false,
        extensions: [[$class: 'SparseCheckoutPaths', sparseCheckoutPaths:[[$class:'SparseCheckoutPath', path:'common/jobs/shell']]]],
        submoduleCfg: [],
        userRemoteConfigs: [[url: gitURL]]])
      sh('compose-pod-build.sh')
    }
  }
  stage('cleanup') {
    cleanWs()
  }
}