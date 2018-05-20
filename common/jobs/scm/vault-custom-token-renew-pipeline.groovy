node {
  wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs:[
    [password: "params.VAULT_TOKEN", var: 'VAULT_TOKEN']
  ]]) {
    stage('Token renew') {
      sh '''#!/usr/bin/env bash
      set -xeuEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      curl -Ssf -X POST \
        -H "X-Vault-Token:${VAULT_TOKEN}" \
        -d "{\\"increment\\": \\"${RENEW_INCREMENT}\\"}" \
        ${VAULT_ADDR}/v1/auth/token/renew-self
      '''
    }
  }
}