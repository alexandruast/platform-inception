#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

# storing minimal data for bootstraping - in production, two separate instances
# will be used - factory and prod, with manual initial repo configuration

# global platform config
curl -Ssf -X PUT \
  -d "${VAULT_ADDR}" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/global/vault_addr" >/dev/null

curl -Ssf -X PUT \
  -d "https://github.com/alexandruast/platform-conf" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/global/conf_scm_url" >/dev/null

curl -Ssf -X PUT \
  -d "*/master" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/global/conf_scm_branch" >/dev/null

# defaults platform config
curl -Ssf -X PUT \
  -d "none" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/defaults/current_build_tag" >/dev/null

# sandbox env global config
curl -Ssf -X PUT \
  -d "docker.io" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/global/docker_registry_address" >/dev/null

curl -Ssf -X PUT \
  -d "platformdemo" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/global/docker_registry_path" >/dev/null
  
curl -Ssf -X PUT \
  -d "${SSH_DEPLOY_ADDRESS}" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/global/ssh_deploy_address" >/dev/null

curl -Ssf -X PUT \
  -d "https://github.com/alexandruast/platform-inception" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/global/builders_scm_url" >/dev/null

curl -Ssf -X PUT \
  -d "*/master" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/global/builders_scm_branch" >/dev/null

curl -Ssf -X PUT \
  -d "builders" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/global/builders_checkout_dir" >/dev/null

curl -Ssf -X PUT \
  -d ".extra-builders" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/global/builders_relative_dir" >/dev/null

# sandbox images config
curl -Ssf -X PUT \
  -d "https://github.com/alexandruast/yaml-to-consul" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/images/sys-py-yaml-to-consul/scm_url" >/dev/null

curl -Ssf -X PUT \
  -d "*/master" \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/images/sys-py-yaml-to-consul/scm_branch" >/dev/null

curl -Ssf -X PUT \
  -d "." \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/sandbox/images/sys-py-yaml-to-consul/checkout_dir" >/dev/null

