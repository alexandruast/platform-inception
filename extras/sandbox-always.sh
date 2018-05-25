#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

ci_admin_pass=$1
sandbox_ip=$2

cd /vagrant/

# waiting for factory jenkins server to be online
scope='factory'
# shellcheck source=factory/.scope
source ${scope}/.scope
export JENKINS_ADMIN_PASS="${ci_admin_pass}"
export JENKINS_ADDR="http://${sandbox_ip}:${JENKINS_PORT}"
./jenkins-query.sh common/is-online.groovy
echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"

# setting up port forwarding rules
sudo sysctl -w net.ipv4.conf.all.route_localnet=1 >/dev/null
sudo iptables -t nat -A PREROUTING -p tcp --dport 8500 -j DNAT --to-destination 127.0.0.1:8500
sudo iptables -t nat -A PREROUTING -p tcp --dport 4646 -j DNAT --to-destination 127.0.0.1:4646

# setting up consul
export CONSUL_HTTP_ADDR="http://consul.service.consul:8500"
export VAULT_ADDR="http://vault.service.consul:8200"
export SSH_DEPLOY_ADDRESS="vagrant@${sandbox_ip}"
./extras/consul-init.sh

JENKINS_ENV_VAR_NAME="CONSUL_HTTP_ADDR" \
  JENKINS_ENV_VAR_VALUE="${CONSUL_HTTP_ADDR}" \
  ./jenkins-query.sh common/env-update.groovy

JENKINS_ENV_VAR_NAME="JENKINS_IP_ADDR" \
  JENKINS_ENV_VAR_VALUE="${sandbox_ip}" \
  ./jenkins-query.sh common/env-update.groovy

# setting up vault, tokens stored on last initialized jenkins server
declare -a ARR_VAULT_SERVERS=(
  "http://127.0.0.1:8200"
)
export VAULT_SERVERS="${ARR_VAULT_SERVERS[*]}"
./extras/vault-init.sh

# garbage collection nodes
curl -Ssf -X PUT "http://127.0.0.1:4646/v1/system/gc"

# bringing up platform services
JENKINS_BUILD_JOB="sandbox-yaml-to-consul-build"
echo "waiting for ${JENKINS_BUILD_JOB} job to complete..."
JENKINS_BUILD_JOB=${JENKINS_BUILD_JOB} \
PLATFORM_ENVIRONMENT="sandbox" \
POD_NAME="yaml-to-consul" \
  ./jenkins-query.sh \
  ./common/jobs/build-basic-pod-job.groovy

JENKINS_BUILD_JOB="consul-data-import"
echo "waiting for ${JENKINS_BUILD_JOB} job to complete..."
JENKINS_BUILD_JOB=${JENKINS_BUILD_JOB} \
  ./jenkins-query.sh \
  ./common/jobs/build-simple-job.groovy

JENKINS_BUILD_JOB="sandbox-fluentd-deploy"
echo "waiting for ${JENKINS_BUILD_JOB} job to complete..."
JENKINS_BUILD_JOB=${JENKINS_BUILD_JOB} \
PLATFORM_ENVIRONMENT="sandbox" \
POD_NAME="fluentd" \
  ./jenkins-query.sh \
  ./common/jobs/build-basic-pod-job.groovy

JENKINS_BUILD_JOB="sandbox-fabio-deploy"
echo "waiting for ${JENKINS_BUILD_JOB} job to complete..."
JENKINS_BUILD_JOB=${JENKINS_BUILD_JOB} \
PLATFORM_ENVIRONMENT="sandbox" \
POD_NAME="fabio" \
  ./jenkins-query.sh \
  ./common/jobs/build-basic-pod-job.groovy

echo "Consul API/UI is available at http://${sandbox_ip}:8500"
echo "Nomad API/UI is available at http://${sandbox_ip}:4646"
echo "Vault API is available at http://${sandbox_ip}:8200"
echo "Fabio UI is available at http://${sandbox_ip}:9998"
echo "Fabio ALB is available at http://${sandbox_ip}:9999"
