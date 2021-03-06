node {
  wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs:[
    [password: "params.VAULT_TOKEN", var: 'VAULT_TOKEN'],
    [password: "params.SECRET_VALUE", var: 'SECRET_VALUE']
  ]]) {
    stage('Update secret') {
      sh '''#!/usr/bin/env bash
      set -xeEuo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      VAULT_ADDR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/global/vault_addr?raw)"
      curl -Ssf -X PUT \
        -H "X-Vault-Token:${VAULT_TOKEN}" \
        -d "{\\"value\\":\\"${SECRET_VALUE}\\"}" \
        "${VAULT_ADDR}/v1/secret/${SECRET_KEY}"
      '''
    }
  }
}