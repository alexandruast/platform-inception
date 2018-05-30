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
  ./jenkins-query.sh common/quiet-cancel.groovy
  echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
done

# setting up consul
export CONSUL_HTTP_ADDR="http://consul.service.consul:8500"
export VAULT_ADDR="http://vault.service.consul:8200"
export SSH_DEPLOY_ADDRESS="vagrant@${server1_ip}"
./extras/consul-init.sh

JENKINS_ENV_VAR_NAME="CONSUL_HTTP_ADDR" \
  JENKINS_ENV_VAR_VALUE="${CONSUL_HTTP_ADDR}" \
  ./jenkins-query.sh common/env-update.groovy

JENKINS_ENV_VAR_NAME="JENKINS_IP_ADDR" \
  JENKINS_ENV_VAR_VALUE="${!ip_addr_var}" \
  ./jenkins-query.sh common/env-update.groovy

# setting up vault, tokens stored on last initialized jenkins server
declare -a ARR_VAULT_SERVERS=(
  "http://${server1_ip}:8200"
  "http://${server2_ip}:8200"
)
export VAULT_SERVERS="${ARR_VAULT_SERVERS[*]}"
./extras/vault-init.sh

# garbage collection nodes
curl -Ssf -X PUT "http://${server1_ip}:4646/v1/system/gc"

# bringing up platform services
JENKINS_BUILD_JOB="sandbox-sys-py-yaml-to-consul-images-build"
echo "waiting for ${JENKINS_BUILD_JOB} job to complete..."
JENKINS_BUILD_JOB=${JENKINS_BUILD_JOB} \
PLATFORM_ENVIRONMENT="sandbox" \
POD_NAME="sys-py-yaml-to-consul" \
  ./jenkins-query.sh \
  ./common/jobs/build-simple-job.groovy

JENKINS_BUILD_JOB="sandbox-consul-data-import"
echo "waiting for ${JENKINS_BUILD_JOB} job to complete..."
JENKINS_BUILD_JOB=${JENKINS_BUILD_JOB} \
  ./jenkins-query.sh \
  ./common/jobs/build-simple-job.groovy

JENKINS_BUILD_JOB="sandbox-sys-fluentd-services-deploy"
echo "waiting for ${JENKINS_BUILD_JOB} job to complete..."
JENKINS_BUILD_JOB=${JENKINS_BUILD_JOB} \
PLATFORM_ENVIRONMENT="sandbox" \
POD_NAME="fluentd" \
  ./jenkins-query.sh \
  ./common/jobs/build-simple-job.groovy

JENKINS_BUILD_JOB="sandbox-sys-fabio-services-deploy"
echo "waiting for ${JENKINS_BUILD_JOB} job to complete..."
JENKINS_BUILD_JOB=${JENKINS_BUILD_JOB} \
PLATFORM_ENVIRONMENT="sandbox" \
POD_NAME="fabio" \
  ./jenkins-query.sh \
  ./common/jobs/build-simple-job.groovy

echo "Consul API/UI is available at http://${server1_ip}:8500"
echo "Nomad API/UI is available at http://${server1_ip}:4646"
echo "Vault API is available at http://${server1_ip}:8200"
echo "Fabio UI is available at http://${server1_ip}:9998"
echo "Fabio ALB is available at http://${server1_ip}:9999"
