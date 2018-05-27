node {
  stage('checkout') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      // get project files
      scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_url?raw").trim()
      scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_branch?raw").trim()
      checkout_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_dir?raw").trim()
      if (checkout_dir == ".") {
        checkout_info = checkout([$class: 'GitSCM',
          branches: [[name: scm_branch]],
          doGenerateSubmoduleConfigurations: false,
          submoduleCfg: [],
          userRemoteConfigs: [[url: scm_url]]]
        )
      } else {
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
      // get builders
      scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/scm_url?raw").trim()
      scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/scm_branch?raw").trim()
      checkout_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/checkout_dir?raw").trim()
      relative_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/relative_dir?raw").trim()
      checkout_info = checkout([$class: 'GitSCM',
        branches: [[name: scm_branch]],
        doGenerateSubmoduleConfigurations: false,
        extensions:[
          [$class: 'SparseCheckoutPaths', sparseCheckoutPaths:[[$class: 'SparseCheckoutPath', path: checkout_dir]]],
          [$class: 'RelativeTargetDirectory', relativeTargetDir: relative_dir]
        ],
        submoduleCfg: [],
        userRemoteConfigs: [[url: scm_url]]]
      )
    }
  }
  stage('build') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      checkout_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/checkout_dir?raw").trim()
      relative_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/relative_dir?raw").trim()
      wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [
        [password: 'thePassword', var: 'MY_PASSWORD']
      ]]) {
        sh("${relative_dir}/${checkout_dir}/compose-pod-build.sh")
      }
    }
  }
  stage('deploy') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      checkout_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/checkout_dir?raw").trim()
      relative_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/builders/relative_dir?raw").trim()
      wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [
        [password: 'thePassword', var: 'MY_PASSWORD']
      ]]) {
        sh("${relative_dir}/${checkout_dir}/compose-pod-deploy.sh")
      }
    }
  }
  stage('cleanup') {
    cleanWs()
  }
}