#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

# recursively delete consul data
curl -Ssf -X DELETE ${CONSUL_HTTP_ADDR}/v1/kv/?recurse >/dev/null
sleep 1
echo "[info] kv data purged from consul"

# storing minimal data for bootstraping - in production, two separate instances
# will be used - factory and prod, with manual initial repo configuration

# bootstrap data
curl -Ssf -X PUT \
  -d "https://github.com/alexandruast/platform-conf" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/bootstrap/scm_url" >/dev/null

curl -Ssf -X PUT \
  -d "*/master" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/bootstrap/scm_branch" >/dev/null

# general configuration
curl -Ssf -X PUT \
  -d "${VAULT_ADDR}" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/vault_address" >/dev/null

curl -Ssf -X PUT \
  -d "docker.io" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/docker_registry_address" >/dev/null

curl -Ssf -X PUT \
  -d "platformdemo" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/docker_registry_path" >/dev/null

curl -Ssf -X PUT \
  -d "${SSH_DEPLOY_ADDRESS}" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/ssh_deploy_address" >/dev/null

# builders data
curl -Ssf -X PUT \
  -d "https://github.com/alexandruast/platform-inception" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/builders/scm_url" >/dev/null

curl -Ssf -X PUT \
  -d "*/devel" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/builders/scm_branch" >/dev/null

curl -Ssf -X PUT \
  -d "builders" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/builders/checkout_dir" >/dev/null

curl -Ssf -X PUT \
  -d ".extra-builders" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/builders/relative_dir" >/dev/null

# we need to build yaml-to-consul
curl -Ssf -X PUT \
  -d "https://github.com/alexandruast/yaml-to-consul" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/yaml-to-consul/scm_url" >/dev/null

curl -Ssf -X PUT \
  -d "*/master" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/yaml-to-consul/scm_branch" >/dev/null

curl -Ssf -X PUT \
  -d "." \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/yaml-to-consul/checkout_dir" >/dev/null

