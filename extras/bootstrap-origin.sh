#!/usr/bin/env bash
# This script tries to emulate a flow that's normally done from an operations workstation
# This server is also the Origin-Jenkins
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
trap 'sudo su -s /bin/bash -c "ssh -S ssh-control-socket -O exit vagrant@${factory_ip:-localhost}" jenkins' EXIT
SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'

ci_admin_pass=$1
ci_origin_json=$2
ci_nodes_json=$3
server_nodes_json=$4
compute_nodes_json=$5

# Getting jq here, manually - workaround for pseudo workstation on origin
sudo curl -LSs https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o /usr/local/bin/jq \
&& sudo chmod +x /usr/local/bin/jq

# Getting some lists of nodes, doing validation
server_nodes="$(echo ${server_nodes_json} | jq -re .[].ip | tr '\n' ',' | sed -e 's/,$/\n/')"
compute_nodes="$(echo ${compute_nodes_json} | jq -re .[].ip | tr '\n' ',' | sed -e 's/,$/\n/')"
concat_json="$(echo ${server_nodes_json} | sed -e 's/]$/,/')$(echo ${compute_nodes_json} | sed -e 's/^\[//')"
nodes_count="$(echo ${concat_json} | jq -re .[].ip | wc -l)"
nodes_count=$((nodes_count - 1))
if [ "${nodes_count}" -le 0 ]; then
  echo "[error] nodes_count:${nodes_count}"
  exit 1
fi

# Getting useful nodes ip
server1_ip="$(echo ${server_nodes_json} | jq -r .[0].ip)"
server2_ip="$(echo ${server_nodes_json} | jq -r .[1].ip)"
factory_ip="$(echo ${ci_nodes_json} | jq --arg hostname "factory" '.[] | select(.hostname==$hostname)' | jq -re .ip)"

# Install ansible
sudo cp provision/extras/epel-release.repo /etc/yum.repos.d/
sudo yum -q -y install ansible

cd /home/vagrant/provision

### --- Begin Origin-Jenkins Setup --- ###
scope='origin'
# shellcheck source=origin/.scope
source ${scope}/.scope
export JENKINS_ADMIN_PASS=${ci_admin_pass}
server_ip="$(echo ${ci_origin_json} | jq -r .ip)"
export JENKINS_ADDR=http://${server_ip}:${JENKINS_PORT}
# dnsmasq to resolve everything using google dns and forward .consul
ANSIBLE_TARGET="127.0.0.1" ANSIBLE_EXTRAVARS="{'dns_servers':['/consul/${server1_ip}','/consul/${server2_ip}','8.8.8.8','8.8.4.4'],'dnsmasq_supersede':true}" ./apl-wrapper.sh ansible/target-${scope}-jenkins.yml
./jenkins-setup.sh
echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
JENKINS_BUILD_JOB=system-${scope}-job-seed ./jenkins-query.sh ./common/jobs/build-simple-job.groovy
### --- End Origin-Jenkins Setup --- ###

jenkins_pk="$(sudo su -s /bin/bash -c 'cat $HOME/.ssh/id_rsa.pub' jenkins)"

### --- Begin Factory/Prod Jenkins Deploy --- ###
# will whitelist origin jenkins user SSH public key into factory and prod authorized_keys
# will whitelist factory/prod jenkins user SSH public keys into servers/nodes authorized_keys
for scope in factory prod; do
  echo "preparing ${scope}-jenkins server..."
  chmod 600 .vagrant/machines/${scope}/virtualbox/private_key
  server_ip="$(echo ${ci_nodes_json} | jq --arg hostname "$scope" '.[] | select(.hostname==$hostname)' | jq -re .ip)"
  jenkins_pk="$(sudo su -s /bin/bash -c 'cat $HOME/.ssh/id_rsa.pub' jenkins)"
  ssh ${SSH_OPTS} -i .vagrant/machines/${scope}/virtualbox/private_key ${server_ip} "if ! grep \"$jenkins_pk\" \$HOME/.ssh/authorized_keys > /dev/null 2>&1; then mkdir -p \$HOME/.ssh; echo $jenkins_pk >> \$HOME/.ssh/authorized_keys; fi"
  sudo su -s /bin/bash -c "ssh ${SSH_OPTS} vagrant@${server_ip} true" jenkins
  echo "waiting for ${scope}-jenkins-deploy job to finish..."
  JENKINS_BUILD_JOB=${scope}-jenkins-deploy ANSIBLE_TARGET=vagrant@${server_ip} ANSIBLE_EXTRAVARS="{}" JENKINS_SCOPE=${scope} ./jenkins-query.sh ./common/jobs/build-jenkins-deploy-job.groovy
  echo "whitelisting ${scope}-jenkins SSH public key to server/compute nodes..."
  jenkins_pk="$(sudo su -s /bin/bash -c "ssh ${SSH_OPTS} vagrant@${server_ip} sudo cat \$HOME/.ssh/id_rsa.pub" jenkins)"
  for i in $(seq 0 ${nodes_count}); do
    hostname="$(echo ${concat_json} | jq -re .[$i].hostname)"
    ip="$(echo ${concat_json} | jq -re .[$i].ip)"
    chmod 600 .vagrant/machines/${hostname}/virtualbox/private_key
    ssh ${SSH_OPTS} -i .vagrant/machines/${hostname}/virtualbox/private_key ${ip} "if ! grep \"${jenkins_pk}\" \$HOME/.ssh/authorized_keys > /dev/null 2>&1; then mkdir -p \$HOME/.ssh; echo ${jenkins_pk} >> \$HOME/.ssh/authorized_keys; fi"
    sudo su -s /bin/bash -c "ssh ${SSH_OPTS} vagrant@${server_ip} \"sudo su -s /bin/bash -c 'ssh ${SSH_OPTS} vagrant@${ip} true' jenkins\"" jenkins
  done
done
### --- End Factory/Prod Jenkins Deploy --- ###

# Copying the bundled SSH key and whitelisting it to all servers/nodes - For Demo/Sandbox purposes only!
mkdir -p $HOME/.ssh/
cp extras/ansible-sandbox.pem /home/vagrant/.ssh/id_rsa
chmod 600 /home/vagrant/.ssh/id_rsa
echo "$(ssh-keygen -y -f /home/vagrant/.ssh/id_rsa) ansible-sandbox" > /home/vagrant/.ssh/id_rsa.pub
sandbox_key="$(cat /home/vagrant/.ssh/id_rsa.pub)"
for i in $(seq 0 ${nodes_count}); do
  hostname="$(echo ${concat_json} | jq -re .[$i].hostname)"
  ip="$(echo ${concat_json} | jq -re .[$i].ip)"
  chmod 600 .vagrant/machines/${hostname}/virtualbox/private_key
  ssh $SSH_OPTS -i .vagrant/machines/${hostname}/virtualbox/private_key ${ip} "if ! grep \"${sandbox_key}\" \$HOME/.ssh/authorized_keys > /dev/null 2>&1; then mkdir -p \$HOME/.ssh; echo ${sandbox_key} >> \$HOME/.ssh/authorized_keys; fi"
  ssh $SSH_OPTS ${ip} true
done

# Establishing SSH tunnel to Factory-Jenkins
JENKINS_SCOPE="factory"
# shellcheck source=factory/.scope
source ./${JENKINS_SCOPE}/.scope
export JENKINS_ADMIN_PASS=${ci_admin_pass}
tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
sudo su -s /bin/bash -c "ssh $SSH_OPTS -f -N -M -S \$HOME/ssh-control-socket -L ${tunnel_port}:127.0.0.1:${JENKINS_PORT} vagrant@${factory_ip}" jenkins
# Nomad server deploy on all server nodes
echo "waiting for infra-generic-nomad-server-deploy job to finish..."
JENKINS_BUILD_JOB="infra-generic-nomad-server-deploy" JENKINS_ADDR="http://127.0.0.1:${tunnel_port}" ANSIBLE_EXTRAVARS="{}" ANSIBLE_TARGET="$(for i in $(echo ${server_nodes} | tr ',' ' ');do printf "vagrant@${i},"; done | sed 's/,$//')" ANSIBLE_SCOPE='server' ANSIBLE_EXTRAVARS="{'serial_value':'100%','service_bind_ip':'{{ansible_host|regex_replace('^vagrant@','')}}'}" ./jenkins-query.sh ./common/jobs/build-infra-generic-deploy-job.groovy

# Joining server cluster members
for i in $(echo $server_nodes | tr ',' ' '); do
  if [ "$i" != "$server1_ip" ]; then
    ssh ${SSH_OPTS} $i "consul join ${server1_ip}"
    ssh ${SSH_OPTS} $i "NOMAD_ADDR=http://${i}:4646 nomad server-join ${server1_ip}"
  fi
done

# Vault server deploy on server1
echo "waiting for infra-generic-vault-server-deploy job to finish..."
JENKINS_BUILD_JOB="infra-generic-vault-server-deploy" JENKINS_ADDR="http://127.0.0.1:${tunnel_port}" ANSIBLE_EXTRAVARS="{}" ANSIBLE_TARGET="vagrant@${server1_ip}" ANSIBLE_SCOPE='server' ./jenkins-query.sh ./common/jobs/build-infra-generic-deploy-job.groovy

# Nomad compute deploy on all compute nodes
echo "waiting for infra-generic-nomad-compute-deploy job to finish..."
JENKINS_BUILD_JOB="infra-generic-nomad-compute-deploy" JENKINS_ADDR="http://127.0.0.1:${tunnel_port}" ANSIBLE_EXTRAVARS="{}" ANSIBLE_TARGET="$(for i in $(echo ${compute_nodes} | tr ',' ' ');do printf "vagrant@${i},"; done | sed 's/,$//')" ANSIBLE_SCOPE='compute' ANSIBLE_EXTRAVARS="{'serial_value':'100%','dns_servers':['/consul/${server1_ip}','/consul/${server2_ip}','8.8.8.8','8.8.4.4'],'dnsmasq_supersede':true,'service_bind_ip':'{{ansible_host|regex_replace('^vagrant@','')}}'}" ./jenkins-query.sh ./common/jobs/build-infra-generic-deploy-job.groovy

