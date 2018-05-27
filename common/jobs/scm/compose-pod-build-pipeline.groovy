node {
  stage('checkout') {
    scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_branch?raw").trim()
    scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_url?raw").trim()
    checkout_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_dir?raw").trim()
    checkout_info = checkout([$class: 'GitSCM',
      branches: [[name: scm_branch]],
      doGenerateSubmoduleConfigurations: false,
      extensions:[
        [$class: 'SparseCheckoutPaths', sparseCheckoutPaths:[[$class: 'SparseCheckoutPath', path: checkout_dir]]]
      ],
      submoduleCfg: [],
      userRemoteConfigs: [[url: scm_url]]]
    )
  }
  stage('build') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/scm_branch?raw").trim()
      scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/scm_url?raw").trim()
      checkout_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/checkout_dir?raw").trim()
      checkout_info = checkout([$class: 'GitSCM',
        branches: [[name: scm_branch]],
        doGenerateSubmoduleConfigurations: false,
        extensions:[
          [$class: 'SparseCheckoutPaths', sparseCheckoutPaths:[[$class: 'SparseCheckoutPath', path: checkout_dir]]],
          [$class: 'RelativeTargetDirectory', relativeTargetDir: '.builders']
        ],
        submoduleCfg: [],
        userRemoteConfigs: [[url: scm_url]]]
      )
      wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [
        [password: 'thePassword', var: 'MY_PASSWORD']]]) {
        sh(".builders/${checkout_dir}/compose-pod-build.sh")
      }
    }
  }
  stage('cleanup') {
    cleanWs()
  }
}