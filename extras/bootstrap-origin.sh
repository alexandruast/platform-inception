#!/usr/bin/env bash
# This script tries to emulate a flow that's normally done from an operations workstation
# This server is also the Origin-Jenkins
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
SSH_CONTROL_SOCKET="/tmp/ssh-control-socket-$(uuidgen)"
trap 'sudo ssh -S "${SSH_CONTROL_SOCKET}" -O exit vagrant@${!ip_addr_var:-192.0.2.255}' EXIT

SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'

force_setup='false'

backup_jenkins_workspace() {
  if  [[ -d "/usr/local/share/jenkins/workspace" ]]; then
    echo "backing up jenkins workspace..."
    sudo tar -cpzf /tmp/jenkins_backup.tar.gz --exclude=jenkins_backup.tar.gz --exclude=config.xml --one-file-system -C /usr/local/share/jenkins ./workspace ./jobs
  fi
}

restore_jenkins_workspace() {
  if  [[ -f "/tmp/jenkins_backup.tar.gz" ]]; then
    echo "restoring jenkins workspace..."
    sudo tar -xpzf /tmp/jenkins_backup.tar.gz -C /usr/local/share/jenkins --numeric-owner
    rm -f /tmp/jenkins_backup.tar.gz
  fi
}

setup_origin_jenkins() {
scope='origin'
# shellcheck source=origin/.scope
source "${scope}/.scope"
export JENKINS_ADMIN_PASS="${ci_admin_pass}"
export JENKINS_ADDR="http://${origin_jenkins_ip}:${JENKINS_PORT}"
ANSIBLE_TARGET="127.0.0.1" \
  ANSIBLE_EXTRAVARS="{'force_setup':${force_setup},'dnsmasq_resolv':'supersede','dns_servers':['8.8.8.8','8.8.4.4']}" \
  ./apl-wrapper.sh ansible/target-${scope}-jenkins.yml
backup_jenkins_workspace
./jenkins-setup.sh
# restore_jenkins_workspace
echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
echo "waiting for system-${scope}-job-seed job to complete..."
JENKINS_BUILD_JOB=system-${scope}-job-seed \
  ./jenkins-query.sh \
  ./common/jobs/build-simple-job.groovy
}

deploy_factory_prod_jenkins() {
  for scope in factory prod; do
    ip_addr_var="${scope}_jenkins_ip"
    # shellcheck source=origin/.scope
    source "${scope}/.scope"
    export JENKINS_ADMIN_PASS="${ci_admin_pass}"
    export JENKINS_ADDR="http://${origin_jenkins_ip}:${JENKINS_PORT}"
    echo "waiting for ${scope}-jenkins-deploy job to complete..."
    JENKINS_BUILD_JOB="${scope}-jenkins-deploy" \
      ANSIBLE_TARGET="${!ip_addr_var}" \
      JENKINS_SCOPE="${scope}" \
      ANSIBLE_EXTRAVARS="{'force_setup':${force_setup},'ansible_user':'vagrant','dnsmasq_resolv':'supersede','dns_servers':['8.8.8.8','8.8.4.4']}" \
      ./jenkins-query.sh \
      ./common/jobs/build-jenkins-deploy-job.groovy
    echo "${scope}-jenkins is online: http://${!ip_addr_var}:${JENKINS_PORT} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
  done
}

# Running infra-generic-nomad-server-deploy job on Factory-Jenkins
nomad_server_deploy() {
  echo "waiting for infra-generic-nomad-server-deploy job to complete..."
  JENKINS_BUILD_JOB="infra-generic-nomad-server-deploy" \
    JENKINS_ADDR="http://127.0.0.1:${tunnel_port}" \
    JENKINS_ADMIN_PASS="${ci_admin_pass}" \
    ANSIBLE_TARGET="$(echo ${server_nodes_json} | jq -r .[].ip | tr '\n' ',' | sed -e 's/,$/\n/')" \
    ANSIBLE_SCOPE='server' \
    ANSIBLE_EXTRAVARS="{'force_setup':${force_setup},'serial_value':'100%','ansible_user':'vagrant','dnsmasq_resolv':'supersede','dns_servers':['/consul/127.0.0.1#8600','8.8.8.8','8.8.4.4'],'service_bind_ip':'{{ansible_host}}'}" \
    ./jenkins-query.sh ./common/jobs/build-infra-generic-deploy-job.groovy  
}

# Running infra-generic-vault-server-deploy job on Factory-Jenkins
vault_server_deploy() {
  echo "waiting for infra-generic-vault-server-deploy job to complete..."
  JENKINS_BUILD_JOB="infra-generic-vault-server-deploy" \
    JENKINS_ADDR="http://127.0.0.1:${tunnel_port}" \
    JENKINS_ADMIN_PASS="${ci_admin_pass}" \
    ANSIBLE_TARGET="${server1_ip}" \
    ANSIBLE_SCOPE='server' \
    ANSIBLE_EXTRAVARS="{'force_setup':${force_setup},'serial_value':'100%','ansible_user':'vagrant','standalone_install':false}" \
    ./jenkins-query.sh ./common/jobs/build-infra-generic-deploy-job.groovy
}

# Running infra-generic-nomad-compute-deploy job on Factory-Jenkins
nomad_compute_deploy() {
  echo "waiting for infra-generic-nomad-compute-deploy job to complete..."
  JENKINS_BUILD_JOB="infra-generic-nomad-compute-deploy" \
    JENKINS_ADDR="http://127.0.0.1:${tunnel_port}" \
    JENKINS_ADMIN_PASS="${ci_admin_pass}" \
    ANSIBLE_SCOPE='compute' \
    ANSIBLE_TARGET="$(echo ${compute_nodes_json} | jq -r .[].ip | tr '\n' ',' | sed -e 's/,$/\n/')" \
    ANSIBLE_EXTRAVARS="{'force_setup':${force_setup},'serial_value':'100%','ansible_user':'vagrant','dnsmasq_resolv':'supersede','dns_servers':['/consul/${server1_ip}','/consul/${server2_ip}','8.8.8.8','8.8.4.4'],'service_bind_ip':'{{ansible_host}}'}" \
    ./jenkins-query.sh ./common/jobs/build-infra-generic-deploy-job.groovy
}

# Establishes SSH tunnel to Factory-Jenkins
create_ssh_tunnel() {
  scope="factory"
  ip_addr_var="${scope}_jenkins_ip"
  # shellcheck source=factory/.scope
  source "${scope}/.scope"
  tunnel_port="$(perl -e 'print int(rand(999)) + 58000')"
  echo "creating ssh tunnel ${tunnel_port}:127.0.0.1:${JENKINS_PORT} to vagrant@${!ip_addr_var}..."
  sudo su -s /bin/bash -c "ssh ${SSH_OPTS} -f -N -M -S  ${SSH_CONTROL_SOCKET} -L ${tunnel_port}:127.0.0.1:${JENKINS_PORT} vagrant@${!ip_addr_var}" jenkins
}

# Joining consul/nomad server cluster members
join_cluster_members() {
  echo "joining consul cluster members..."
  ssh ${SSH_OPTS} ${server1_ip} "consul join ${server2_ip}"
  echo "joining nomad cluster members..."
  ssh ${SSH_OPTS} ${server1_ip} "NOMAD_ADDR=http://${server1_ip}:4646 nomad server-join ${server2_ip}"
}

install_jq() {
  sudo curl -LSs https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o /usr/local/bin/jq \
  && sudo chmod +x /usr/local/bin/jq
}

install_pip() {
  curl -LSs "https://bootstrap.pypa.io/get-pip.py" | sudo python
}

install_ansible() {
  sudo pip install ansible==2.4.4.0
}

# Overwrites Origin-Jenkins ssh key pair, created by Ansible in previous steps
overwrite_origin_keypair() {
  cat /home/vagrant/.ssh/id_rsa | sudo tee /home/jenkins/.ssh/id_rsa >/dev/null
  ssh-keygen -y -f "$HOME/.ssh/id_rsa" | sudo tee /home/jenkins/.ssh/id_rsa.pub >/dev/null
}

# Overwrites Factory/Prod-Jenkins ssh key pair, created by Ansible in previous steps
overwrite_factory_prod_jenkins_keypair() {
  echo "overwriting factory/prod jenkins keypair..."
  for scope in factory prod; do
    ip_addr_var="${scope}_jenkins_ip"
    cat /home/vagrant/.ssh/id_rsa | ssh ${SSH_OPTS} ${!ip_addr_var} sudo tee /home/jenkins/.ssh/id_rsa >/dev/null
    ssh-keygen -y -f "$HOME/.ssh/id_rsa" | ssh ${SSH_OPTS} ${!ip_addr_var} sudo tee /home/jenkins/.ssh/id_rsa.pub >/dev/null
  done
}

ci_admin_pass=$1
ci_origin_json=$2
ci_factory_json=$3
ci_prod_json=$4
server_nodes_json=$5
compute_nodes_json=$6

sudo yum -q -y install python libselinux-python

which pip >/dev/null || install_pip
which ansible >/dev/null || install_ansible
which jq >/dev/null || install_jq

origin_jenkins_ip="$(echo ${ci_origin_json} | jq -r .ip)"
factory_jenkins_ip="$(echo ${ci_factory_json} | jq -r .ip)"
prod_jenkins_ip="$(echo ${ci_prod_json} | jq -r .ip)"
server1_ip="$(echo ${server_nodes_json} | jq -r .[0].ip)"
server2_ip="$(echo ${server_nodes_json} | jq -r .[1].ip)"

cd /vagrant/

curr_ansible_dir_md5="$(tar -cf - -C /vagrant/ansible ./ | md5sum | cut -d' ' -f1)"

if [[ -f "/tmp/ansible-dir-md5" ]]; then
  prev_ansible_dir_md5="$(cat /tmp/ansible-dir-md5 | head -1 | cut -d' ' -f1)"
  if [[ "${curr_ansible_dir_md5}" != "${prev_ansible_dir_md5}" ]]; then
    force_setup='true'
  fi
fi

setup_origin_jenkins
overwrite_origin_keypair
deploy_factory_prod_jenkins
overwrite_factory_prod_jenkins_keypair
create_ssh_tunnel
nomad_server_deploy
join_cluster_members
vault_server_deploy
nomad_compute_deploy

echo "${curr_ansible_dir_md5}" > /tmp/ansible-dir-md5
