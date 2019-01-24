node {
  stage('checkout') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      // get project files
      // ToDo: Retrieve this with native API interaction
      scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/${PLATFORM_ENVIRONMENT}/${SERVICE_CATEGORY}/${SERVICE_NAME}/scm_url?raw").trim()
      scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/${PLATFORM_ENVIRONMENT}/${SERVICE_CATEGORY}/${SERVICE_NAME}/scm_branch?raw").trim()
      checkout_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/${PLATFORM_ENVIRONMENT}/${SERVICE_CATEGORY}/${SERVICE_NAME}/checkout_dir?raw").trim()
      if (checkout_dir == ".") {
        checkout_info = checkout([$class: 'GitSCM',
          branches: [[name: scm_branch]],
          doGenerateSubmoduleConfigurations: false,
          extensions:[
            [$class: 'CleanBeforeCheckout']
          ],
          submoduleCfg: [],
          userRemoteConfigs: [[url: scm_url]]]
        )
      } else {
        checkout_info = checkout([$class: 'GitSCM',
          branches: [[name: scm_branch]],
          doGenerateSubmoduleConfigurations: false,
          extensions:[
            [$class: 'CleanBeforeCheckout'],
            [$class: 'SparseCheckoutPaths', sparseCheckoutPaths:[[$class: 'SparseCheckoutPath', path: checkout_dir]]]
          ],
          submoduleCfg: [],
          userRemoteConfigs: [[url: scm_url]]]
        )
      }
      // get builders
      // ToDo: Retrieve this with native API interaction
      builders_scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/${PLATFORM_ENVIRONMENT}/global/builders_scm_url?raw").trim()
      builders_scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/${PLATFORM_ENVIRONMENT}/global/builders_scm_branch?raw").trim()
      builders_checkout_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/${PLATFORM_ENVIRONMENT}/global/builders_checkout_dir?raw").trim()
      builders_relative_dir = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/${PLATFORM_ENVIRONMENT}/global/builders_relative_dir?raw").trim()
      checkout_info = checkout([$class: 'GitSCM',
        branches: [[name: builders_scm_branch]],
        doGenerateSubmoduleConfigurations: false,
        extensions:[
          [$class: 'CleanBeforeCheckout'],
          [$class: 'SparseCheckoutPaths', sparseCheckoutPaths:[[$class: 'SparseCheckoutPath', path: builders_checkout_dir]]],
          [$class: 'RelativeTargetDirectory', relativeTargetDir: builders_relative_dir]
        ],
        submoduleCfg: [],
        userRemoteConfigs: [[url: builders_scm_url]]]
      )
      sh("${builders_relative_dir}/${builders_checkout_dir}/compose-service-build-env.sh")
    }
  }
  stage('build') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      sh '''#!/usr/bin/env bash
        source "${WORKSPACE}/.build-secrets"
        source "${WORKSPACE}/.build-env"
        set -eEuo pipefail
        "${BUILDERS_RELATIVE_DIR}/${BUILDERS_CHECKOUT_DIR}/compose-service-build.sh"
      '''
    }
  }
  if ( SERVICE_CATEGORY == "services" ) {
    stage('deploy') {
      withCredentials([
          string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
          string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
      ]) {
        sh '''#!/usr/bin/env bash
          set -eEuo pipefail
          source "${WORKSPACE}/.build-secrets"
          source "${WORKSPACE}/.build-env"
          "${BUILDERS_RELATIVE_DIR}/${BUILDERS_CHECKOUT_DIR}/compose-service-deploy.sh"
        '''
      }
    }
  }
  stage('cleanup') {
    sh('shred -u "${WORKSPACE}/.build-secrets"')
  }
}