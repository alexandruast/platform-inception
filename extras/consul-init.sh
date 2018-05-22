#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

# recursively delete consul data
curl -Ssf -X DELETE ${CONSUL_HTTP_ADDR}/v1/kv/?recurse >/dev/null
sleep 1
echo "[info] kv data purged from consul"

# storing minimal data for bootstraping - in production, two separate instances
# will be used - factory and prod, with manual initial repo configuration

curl -Ssf -X PUT \
  -d "https://github.com/alexandruast/platform-data" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/bootstrap/scm_url" >/dev/null

curl -Ssf -X PUT \
  -d "*/master" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/bootstrap/scm_branch" >/dev/null

  curl -Ssf -X PUT \
    -d "https://github.com/alexandruast/yaml-to-consul" \
    "${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/sandbox/yaml-to-consul/scm_url" >/dev/null

  curl -Ssf -X PUT \
    -d "*/master" \
    "${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/sandbox/yaml-to-consul/scm_branch" >/dev/null

curl -Ssf -X PUT \
  -d "${VAULT_ADDR}" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/vault_address" >/dev/null

curl -Ssf -X PUT \
  -d "docker.io" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/docker_registry_address" >/dev/null

curl -Ssf -X PUT \
  -d "platformdemo" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/docker_registry_path" >/dev/null

curl -Ssf -X PUT \
  -d "${SSH_DEPLOY_ADDRESS}" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/sandbox/ssh_deploy_address" >/dev/null

