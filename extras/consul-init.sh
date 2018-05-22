#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

# recursively delete consul data
curl -Ssf -X DELETE ${CONSUL_HTTP_ADDR}/v1/kv/?recurse >/dev/null
sleep 1
echo "[info] kv data purged from consul"

# storing minimal data for bootstraping
curl -Ssf -X PUT \
  -d "${VAULT_ADDR}" \
  "${CONSUL_HTTP_ADDR}/v1/kv/vault_address" >/dev/null

curl -Ssf -X PUT \
  -d "docker.io" \
  "${CONSUL_HTTP_ADDR}/v1/kv/docker_registry_address" >/dev/null

curl -Ssf -X PUT \
  -d "platformdemo" \
  "${CONSUL_HTTP_ADDR}/v1/kv/docker_registry_path" >/dev/null

curl -Ssf -X PUT \
  -d "${SSH_DEPLOY_ADDRESS}" \
  "${CONSUL_HTTP_ADDR}/v1/kv/ssh_deploy_address" >/dev/null

  curl -Ssf -X PUT \
    -d "https://github.com/alexandruast/yaml-to-consul" \
    "${CONSUL_HTTP_ADDR}/v1/kv/services/yaml-to-consul/sandbox/scm_url" >/dev/null
  
  curl -Ssf -X PUT \
    -d "*/master" \
    "${CONSUL_HTTP_ADDR}/v1/kv/services/yaml-to-consul/sandbox/scm_branch" >/dev/null

JENKINS_ENV_VAR_NAME="CONSUL_HTTP_ADDR" \
  JENKINS_ENV_VAR_VALUE="http://consul.service.consul:8500" \
  ./jenkins-query.sh common/env-update.groovy

