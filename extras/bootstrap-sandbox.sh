#!/usr/bin/env bash
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

ci_admin_pass=$1

install_jq() {
  sudo curl -LSs https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o /usr/local/bin/jq \
  && sudo chmod +x /usr/local/bin/jq
}

install_pip() {
  curl -LSs "https://bootstrap.pypa.io/get-pip.py" | sudo python
}

sudo yum -q -y install python libselinux-python
which pip >/dev/null || install_pip
sudo pip install ansible==2.5.2
which jq >/dev/null || install_jq

cd /vagrant/

source "factory/.scope"
export JENKINS_ADMIN_PASS="${ci_admin_pass}"
export JENKINS_ADDR="http://127.0.0.1:${JENKINS_PORT}"
ANSIBLE_TARGET="127.0.0.1" \
  ANSIBLE_EXTRAVARS="{'dnsmasq_resolv':'supersede','dns_servers':['/consul/127.0.0.1#8600','8.8.8.8','8.8.4.4']}" \
  ./apl-wrapper.sh ansible/target-sandbox.yml
./jenkins-setup.sh
echo "factory-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
echo "waiting for system-factory-job-seed job to complete..."
JENKINS_BUILD_JOB=system-factory-job-seed \
  ./jenkins-query.sh \
  ./common/jobs/build-simple-job.groovy

# Overwrites ssh key pair, created by Ansible in previous steps
cat /home/vagrant/.ssh/id_rsa | sudo tee /home/jenkins/.ssh/id_rsa >/dev/null
ssh-keygen -y -f "$HOME/.ssh/id_rsa" | sudo tee /home/jenkins/.ssh/id_rsa.pub >/dev/null
