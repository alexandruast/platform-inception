node {
  stage('Renew Token') {
    withCredentials([string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN')]) {
      sh '''#!/usr/bin/env bash
      set -xeuEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      VAULT_ADDR="http://vault.service.consul:8200"
      curl -Ssf -X POST \
        -H "X-Vault-Token:${VAULT_TOKEN}" \
        -d \"{\"increment\": \"96h\"}" \
        ${VAULT_ADDR}/v1/auth/token/renew-self
      '''
    }
  }
}