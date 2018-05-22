#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

# recursively delete consul data
curl -Ssf -X DELETE ${CONSUL_HTTP_ADDR}/v1/kv/${PLATFORM_ENV}?recurse >/dev/null
sleep 1
echo "[info] ${PLATFORM_ENV} data purged from consul"

# storing minimal data for bootstraping
curl -Ssf -X PUT \
  -d ${VAULT_ADDR} \
  ${CONSUL_HTTP_ADDR}/v1/kv/${PLATFORM_ENV}/vault_address >/dev/null
