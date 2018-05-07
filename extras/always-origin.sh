#!/usr/bin/env bash
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

exit 0

ci_admin_pass=$1
ci_origin_json=$2
ci_nodes_json=$3
server_nodes_json=$4

cd /home/vagrant/provision

concat_json="$(echo ${ci_nodes_json} | sed -e 's/]$/,/')${ci_origin_json}]"

for scope in origin factory prod; do
  export JENKINS_NULL='null'
  for v in $(env | grep '^JENKINS_' | cut -f1 -d'='); do unset $v; done
  # shellcheck source=origin/.scope
  source ${scope}/.scope
  export JENKINS_ADMIN_PASS=$ci_admin_pass
  server_ip="$(echo ${concat_json} | jq --arg hostname "$scope" '.[] | select(.hostname==$hostname)' | jq -re .ip)"
  export JENKINS_ADDR=http://${server_ip}:${JENKINS_PORT}
  ./jenkins-query.sh common/is-online.groovy
  echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
done

server1_ip="$(echo ${server_nodes_json} | jq -r .[0].ip)"

# Setting up vault demo
VAULT_ADDR="http://${server1_ip}:8200" CONSUL_HTTP_ADDR="http://${server1_ip}:8500" ./extras/vault-demo.sh

# Garbage collect nodes
curl --silent -X PUT "http://${server1_ip}:4646/v1/system/gc"

echo "Consul UI is available at http://${server1_ip}:8500"
echo "Nomad UI is available at http://${server1_ip}:4646"
echo "Vault is available at http://${server1_ip}:8200"
