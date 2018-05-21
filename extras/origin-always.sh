#!/usr/bin/env bash
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

ci_admin_pass=$1
ci_origin_json=$2
ci_factory_json=$3
ci_prod_json=$4
server_nodes_json=$5

origin_jenkins_ip="$(echo ${ci_origin_json} | jq -re .ip)"
factory_jenkins_ip="$(echo ${ci_factory_json} | jq -re .ip)"
prod_jenkins_ip="$(echo ${ci_prod_json} | jq -re .ip)"
server1_ip="$(echo ${server_nodes_json} | jq -re .[0].ip)"
server2_ip="$(echo ${server_nodes_json} | jq -re .[1].ip)"

cd /vagrant/

# waiting for jenkins servers to be online
for scope in origin prod factory; do
  ip_addr_var="${scope}_jenkins_ip"
  export JENKINS_NULL='null'
  for v in $(env | grep '^JENKINS_' | cut -f1 -d'='); do unset $v; done
  # shellcheck source=origin/.scope
  source "${scope}/.scope"
  export JENKINS_ADMIN_PASS="${ci_admin_pass}"
  export JENKINS_ADDR="http://${!ip_addr_var}:${JENKINS_PORT}"
  ./jenkins-query.sh common/is-online.groovy
  echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
done

# setting up vault, tokens stored on last initialized jenkins server
export CONSUL_HTTP_ADDR="http://consul.service.consul:8500"
export VAULT_ADDR="http://vault.service.consul:8200"
export VAULT_SERVERS=(
  "http://${server1_ip}:8200"
  "http://${server2_ip}:8200"
)
./extras/vault-init.sh

# garbage collection nodes
curl --silent -X PUT "http://${server1_ip}:4646/v1/system/gc"

echo "Consul API/UI is available at http://${server1_ip}:8500"
echo "Nomad API/UI is available at http://${server1_ip}:4646"
echo "Vault API is available at http://${server1_ip}:8200"
