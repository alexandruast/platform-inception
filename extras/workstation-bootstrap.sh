#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

workstation_ip=$1
service_network_interface=$2

install_pip() {
  curl -LSs "https://bootstrap.pypa.io/get-pip.py" | sudo python
}

install_ansible() {
  sudo pip install ansible==2.7.5
}

install_jq() {
  sudo curl -LSs https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o /usr/local/bin/jq \
  && sudo chmod +x /usr/local/bin/jq
}


sudo yum -q -y install python libselinux-python
which pip >/dev/null || install_pip
which ansible >/dev/null || install_ansible
which jq >/dev/null || install_jq

cd /vagrant/

ANSIBLE_TARGET="127.0.0.1" \
  ANSIBLE_EXTRAVARS="{'service_bind_ip':'${workstation_ip}','service_network_interface':'${service_network_interface}','docker_host':'tcp://0.0.0.0:2375'}" \
  ./apl-wrapper.sh ansible/target-workstation.yml

