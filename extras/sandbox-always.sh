#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

ci_admin_pass=$1
sandbox_ip=$2

cd /vagrant/

source factory/.scope
export JENKINS_ADMIN_PASS=${ci_admin_pass}
export JENKINS_ADDR=http://${sandbox_ip}:${JENKINS_PORT}
./jenkins-query.sh common/is-online.groovy
echo "factory-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"

# setting up port forwarding rules
sudo sysctl -w net.ipv4.conf.all.route_localnet=1
sudo iptables -t nat -A PREROUTING -p tcp --dport 8500 -j DNAT --to-destination 127.0.0.1:8500
sudo iptables -t nat -A PREROUTING -p tcp --dport 4646 -j DNAT --to-destination 127.0.0.1:4646

# setting up vault
VAULT_CLUSTER_IPS="${sandbox_ip}" ./extras/vault-init.sh

# garbage collection nodes
curl --silent -X PUT "http://${sandbox_ip}:4646/v1/system/gc"

echo "Consul API/UI is available at http://${sandbox_ip}:8500"
echo "Nomad API/UI is available at http://${sandbox_ip}:4646"
echo "Vault API is available at http://${sandbox_ip}:8200"
