#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

ci_admin_pass=$1
sandbox_ip=$2
consul_acl_master_token="0d5e7431-651f-4ce1-a97f-e1257cc047de"

install_pip() {
  curl -LSs "https://bootstrap.pypa.io/get-pip.py" | sudo python
}

install_ansible() {
  sudo pip install ansible==2.5.2
}

install_jq() {
  sudo curl -LSs https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o /usr/local/bin/jq \
  && sudo chmod +x /usr/local/bin/jq
}

overwrite_factory_keypair() {
  # Overwrites ssh key pair, created by Ansible in previous steps
  cat /home/vagrant/.ssh/id_rsa | sudo tee /home/jenkins/.ssh/id_rsa >/dev/null
  ssh-keygen -y -f "$HOME/.ssh/id_rsa" | sudo tee /home/jenkins/.ssh/id_rsa.pub >/dev/null
}

setup_sandbox() {
  source "factory/.scope"
  export JENKINS_ADMIN_PASS="${ci_admin_pass}"
  export JENKINS_ADDR="http://${sandbox_ip}:${JENKINS_PORT}"
  ANSIBLE_TARGET="127.0.0.1" \
    ANSIBLE_EXTRAVARS="{'consul_acl_master_token':'${consul_acl_master_token}','dnsmasq_resolv':'supersede','service_bind_ip':'${sandbox_ip}','service_network_interface':'enp0s8','dns_servers':['/consul/127.0.0.1#8600','8.8.8.8','8.8.4.4']}" \
    ./apl-wrapper.sh ansible/target-sandbox.yml
  ./jenkins-setup.sh
  echo "factory-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
  JENKINS_BUILD_JOB="system-factory-job-seed"
  echo "waiting for ${JENKINS_BUILD_JOB} job to complete..."
  JENKINS_BUILD_JOB=${JENKINS_BUILD_JOB} \
    ./jenkins-query.sh \
    ./common/jobs/build-simple-job.groovy
}

sudo yum -q -y install python libselinux-python
which pip >/dev/null || install_pip
which ansible >/dev/null || install_ansible
which jq >/dev/null || install_jq

cd /vagrant/

setup_sandbox
overwrite_factory_keypair

