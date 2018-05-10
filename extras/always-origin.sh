#!/usr/bin/env bash
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

ci_admin_pass=$1
ci_origin_json=$2
ci_factory_json=$3
ci_prod_json=$4
server_nodes_json=$5

origin_jenkins_ip="$(echo ${ci_origin_json} | jq -r .ip)"
factory_jenkins_ip="$(echo ${ci_factory_json} | jq -r .ip)"
prod_jenkins_ip="$(echo ${ci_prod_json} | jq -r .ip)"
server1_ip="$(echo ${server_nodes_json} | jq -r .[0].ip)"

cd /vagrant/
for scope in origin factory prod; do
  echo "waiting for ${scope}-jenkins to be online..."
  ip_addr_var="${scope}_jenkins_ip"
  export JENKINS_NULL='null'
  for v in $(env | grep '^JENKINS_' | cut -f1 -d'='); do unset $v; done
  # shellcheck source=origin/.scope
  source ${scope}/.scope
  export JENKINS_ADMIN_PASS=$ci_admin_pass
  export JENKINS_ADDR=http://${!ip_addr_var}:${JENKINS_PORT}
  ./jenkins-query.sh common/is-online.groovy
  echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
done

echo "setting up vault demo..."
VAULT_ADDR="http://${server1_ip}:8200" CONSUL_HTTP_ADDR="http://${server1_ip}:8500" ./extras/vault-demo.sh

echo "starting garbage collection on nomad..."
curl --silent -X PUT "http://${server1_ip}:4646/v1/system/gc"

echo "Consul UI is available at http://${server1_ip}:8500"
echo "Nomad UI is available at http://${server1_ip}:4646"
echo "Vault is available at http://${server1_ip}:8200"
