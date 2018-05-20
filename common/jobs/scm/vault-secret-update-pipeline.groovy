node {
  wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs:[
    [password: "params.VAULT_TOKEN", var: 'VAULT_TOKEN'],
    [password: "params.SECRET_VALUE", var: 'SECRET_VALUE']
  ]]) {
    stage('Update secret') {
      sh '''#!/usr/bin/env bash
      set -xeuEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      curl -Ssf -X PUT \
        -H "X-Vault-Token:${VAULT_TOKEN}" \
        -d "{\\"value\\":\\"${SECRET_VALUE}\\"}" \
        ${VAULT_ADDR}/v1/secret/${SECRET_KEY}
      '''
    }
  }
}