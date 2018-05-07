#!/usr/bin/env bash
# This script tries to emulate a flow that's normally done from an operations workstation
# This server is also the Origin-Jenkins
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
SSH_CONTROL_SOCKET="/tmp/ssh-control-socket-$(uuidgen)"
trap 'ssh -S "${SSH_CONTROL_SOCKET}" -O exit vagrant@${factory_jenkins_ip:-192.0.2.255}' EXIT
SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'

ci_admin_pass=$1
ci_origin_json=$2
ci_factory_json=$3
ci_prod_json=$4
server_nodes_json=$5
compute_nodes_json=$6

# Getting jq here, manually - workaround for pseudo workstation on origin
sudo curl -LSs https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o /usr/local/bin/jq \
&& sudo chmod +x /usr/local/bin/jq

# Getting some lists of nodes, doing validation
server_nodes_ips="$(echo ${server_nodes_json} | jq -re .[].ip | tr '\n' ',' | sed -e 's/,$/\n/')"
compute_nodes_ips="$(echo ${compute_nodes_json} | jq -re .[].ip | tr '\n' ',' | sed -e 's/,$/\n/')"
concat_json="$(echo ${server_nodes_json} | sed -e 's/]$/,/')$(echo ${compute_nodes_json} | sed -e 's/^\[//')"
nodes_count="$(echo ${concat_json} | jq -re .[].ip | wc -l)"
nodes_count=$((nodes_count - 1))
if [ "${nodes_count}" -le 0 ]; then
  echo "[error] nodes_count:${nodes_count}"
  exit 1
fi

origin_jenkins_ip="$(echo ${ci_origin_json} | jq -r .ip)"
factory_jenkins_ip="$(echo ${ci_factory_json} | jq -r .ip)"
prod_jenkins_ip="$(echo ${ci_prod_json} | jq -r .ip)"
server1_ip="$(echo ${server_nodes_json} | jq -r .[0].ip)"
server2_ip="$(echo ${server_nodes_json} | jq -r .[1].ip)"

# Install ansible
sudo cp provision/extras/epel-release.repo /etc/yum.repos.d/
sudo yum -q -y install ansible

cd /home/vagrant/provision

# Setup Origin-Jenkins
scope='origin'
# shellcheck source=origin/.scope
source "${scope}/.scope"
export JENKINS_ADMIN_PASS="${ci_admin_pass}"
export JENKINS_ADDR="http://${origin_jenkins_ip}:${JENKINS_PORT}"
# dnsmasq to resolve everything using google dns and forward .consul
ANSIBLE_TARGET="127.0.0.1" \
  ANSIBLE_EXTRAVARS="{'dns_servers':['/consul/${server1_ip}','/consul/${server2_ip}','8.8.8.8','8.8.4.4']}" \
  ./apl-wrapper.sh ansible/target-${scope}-jenkins.yml
# Running Jenkins setup script
./jenkins-setup.sh
echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
JENKINS_BUILD_JOB=system-${scope}-job-seed \
  ./jenkins-query.sh \
  ./common/jobs/build-simple-job.groovy

# Overwriting Origin-Jenkins ssh key pair, created by Ansible in previous steps
cat /home/vagrant/.ssh/id_rsa | sudo tee /home/jenkins/.ssh/id_rsa >/dev/null

for scope in factory prod; do
  ip_addr_var="${scope}_jenkins_ip"
  # shellcheck source=origin/.scope
  source "${scope}/.scope"
  export JENKINS_ADMIN_PASS="${ci_admin_pass}"
  export JENKINS_ADDR="http://${!ip_addr_var}:${JENKINS_PORT}"
  JENKINS_BUILD_JOB="${scope}-jenkins-deploy" \
    ANSIBLE_TARGET="vagrant@${!ip_addr_var}" \
    ANSIBLE_EXTRAVARS="{}" \
    JENKINS_SCOPE="${scope}" \
    ./jenkins-query.sh \
    ./common/jobs/build-jenkins-deploy-job.groovy
  echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
done

exit 0

### --- Begin Factory-Jenkins Deploy --- ###
### --- End Factory-Jenkins Deploy --- ###

### --- Begin Factory/Prod Jenkins Deploy --- ###
# will whitelist Origin-Jenkins user public key into factory and prod authorized_keys
# will whitelist Factory/Prod Jenkins users public keys into servers/nodes authorized_keys
for scope in factory prod; do
  
  echo "waiting for ${scope}-jenkins-deploy job to finish..."
  JENKINS_BUILD_JOB="${scope}-jenkins-deploy" \
    ANSIBLE_TARGET="vagrant@${jenkins_ip}" \
    ANSIBLE_EXTRAVARS="{}" \
    JENKINS_SCOPE="${scope}" \
    ./jenkins-query.sh \
    ./common/jobs/build-jenkins-deploy-job.groovy
  echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
  echo "whitelisting ${scope}-jenkins public key to server/compute nodes..."
  loop_jenkins_pk="$(sudo su -s /bin/bash -c "ssh ${SSH_OPTS} vagrant@${jenkins_ip} sudo cat \$HOME/.ssh/id_rsa.pub" jenkins)"
  for ip in $(seq 0 ${nodes_count}); do
    hostname="$(echo ${concat_json} | jq -re .[${ip}].hostname)"
    ip="$(echo ${concat_json} | jq -re .[${ip}].ip)"
    chmod 600 .vagrant/machines/${hostname}/virtualbox/private_key
    ssh ${SSH_OPTS} -i .vagrant/machines/${hostname}/virtualbox/private_key ${ip} \
      "if ! grep \"${loop_jenkins_pk}\" \$HOME/.ssh/authorized_keys > /dev/null 2>&1; then mkdir -p \$HOME/.ssh; echo ${loop_jenkins_pk} >> \$HOME/.ssh/authorized_keys; fi"
    sudo su -s /bin/bash -c "ssh ${SSH_OPTS} vagrant@${jenkins_ip} \"sudo su -s /bin/bash -c 'ssh ${SSH_OPTS} vagrant@${ip} true' jenkins\"" jenkins
  done
done
### --- End Factory/Prod Jenkins Deploy --- ###


# Establishing SSH tunnel to Factory-Jenkins
scope="factory"
# shellcheck source=factory/.scope
source "${scope}/.scope"
tunnel_port="$(perl -e 'print int(rand(999)) + 58000')"
sudo su -s /bin/bash -c "ssh ${SSH_OPTS} -f -N -M -S  ${SSH_CONTROL_SOCKET} -L ${tunnel_port}:127.0.0.1:${JENKINS_PORT} vagrant@${factory_jenkins_ip}" jenkins

# Running infra-generic-nomad-server-deploy job on Factory-Jenkins
echo "waiting for infra-generic-nomad-server-deploy job to finish..."
JENKINS_BUILD_JOB="infra-generic-nomad-server-deploy" \
  JENKINS_ADDR="http://127.0.0.1:${tunnel_port}" \
  JENKINS_ADMIN_PASS="${ci_admin_pass}" \
  ANSIBLE_TARGET="${server1_ip},${server2_ip}" \
  ANSIBLE_SCOPE='server' \
  ANSIBLE_EXTRAVARS="{'ansible_ssh_user':'vagrant','service_bind_ip':'{{ansible_host}}'}" \
  ./jenkins-query.sh ./common/jobs/build-infra-generic-deploy-job.groovy

# Joining consul/nomad server cluster members
ssh ${SSH_OPTS} ${server1_ip} "consul join ${server2_ip}"
ssh ${SSH_OPTS} ${server1_ip} "NOMAD_ADDR=http://${server1_ip}:4646 nomad server-join ${server2_ip}"

# Running infra-generic-vault-server-deploy job on Factory-Jenkins
echo "waiting for infra-generic-vault-server-deploy job to finish..."
JENKINS_BUILD_JOB="infra-generic-vault-server-deploy" \
  JENKINS_ADDR="http://127.0.0.1:${tunnel_port}" \
  JENKINS_ADMIN_PASS="${ci_admin_pass}" \
  ANSIBLE_TARGET="vagrant@${server1_ip}" \
  ANSIBLE_SCOPE='server' \
  ANSIBLE_EXTRAVARS="{'ansible_ssh_user':'vagrant'}" \
  ./jenkins-query.sh ./common/jobs/build-infra-generic-deploy-job.groovy

# Running infra-generic-nomad-compute-deploy job on Factory-Jenkins
echo "waiting for infra-generic-nomad-compute-deploy job to finish..."
JENKINS_BUILD_JOB="infra-generic-nomad-compute-deploy" \
  JENKINS_ADDR="http://127.0.0.1:${tunnel_port}" \
  JENKINS_ADMIN_PASS="${ci_admin_pass}" \
  ANSIBLE_SCOPE='compute' \
  ANSIBLE_TARGET="$(for ip in $(echo ${compute_nodes_ips} | tr ',' ' ');do printf "vagrant@${ip},"; done | sed 's/,$//')" \
  ANSIBLE_EXTRAVARS="{'ansible_ssh_user':'vagrant'}" \
  ANSIBLE_EXTRAVARS="{'ansible_ssh_user':'vagrant','dns_servers':['/consul/${server1_ip}','/consul/${server2_ip}','8.8.8.8','8.8.4.4'],'service_bind_ip':'{{ansible_host}}'}" \
  ./jenkins-query.sh ./common/jobs/build-infra-generic-deploy-job.groovy

