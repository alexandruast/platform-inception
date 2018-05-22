node {
  stage('checkout') {
    gitBranch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/bootstrap/scm_branch?raw").trim()
    gitURL = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/bootstrap/scm_url?raw").trim()
    checkout_info = checkout([$class: 'GitSCM', 
      branches: [[name: gitBranch]], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: gitURL]]])
  }
  stage('import') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    exit 0
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}
