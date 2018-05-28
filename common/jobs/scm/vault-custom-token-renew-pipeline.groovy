node {
  wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs:[
    [password: "params.VAULT_TOKEN", var: 'VAULT_TOKEN']
  ]]) {
    stage('Token renew') {
      sh '''#!/usr/bin/env bash
      set -xeEuo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      VAULT_ADDR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/vault_address?raw)"
      curl -Ssf -X POST \
        -H "X-Vault-Token:${VAULT_TOKEN}" \
        -d "{\\"increment\\": \\"${RENEW_INCREMENT}\\"}" \
        "${VAULT_ADDR}/v1/auth/token/renew-self"
      '''
    }
  }
}