#!/usr/bin/env bash
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
SSH_OPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'

ci_admin_pass=$1
ci_origin_json=$2
ci_nodes_json=$3
server_nodes_json=$4
compute_nodes_json=$5

mkdir -p $HOME/.ssh/
cp provision/extras/ansible-sandbox.pem /home/vagrant/.ssh/id_rsa
chmod 600 /home/vagrant/.ssh/id_rsa
echo "$(ssh-keygen -y -f /home/vagrant/.ssh/id_rsa) ansible-sandbox" > /home/vagrant/.ssh/id_rsa.pub

sudo cp provision/extras/epel-release.repo /etc/yum.repos.d/
sudo yum -q -y install ansible

cd /home/vagrant/provision
ANSIBLE_TARGET="127.0.0.1" ./apl-wrapper.sh ansible/base.yml

server1_ip="$(echo ${server_nodes_json} | jq -r .[0].ip)"
server2_ip="$(echo ${server_nodes_json} | jq -r .[1].ip)"

ANSIBLE_TARGET="127.0.0.1" ANSIBLE_EXTRAVARS="{'authorized_keys':[{'user':'vagrant','file':'/home/vagrant/.ssh/id_rsa.pub'}]}" ./apl-wrapper.sh ansible/authorized-keys.yml
ANSIBLE_TARGET="127.0.0.1" ANSIBLE_EXTRAVARS="{'dns_servers':['/consul/${server1_ip}','/consul/${server2_ip}','8.8.8.8','8.8.4.4'],'dnsmasq_supersede':true}" ./apl-wrapper.sh ansible/dnsmasq.yml
ANSIBLE_TARGET="127.0.0.1" ./apl-wrapper.sh ansible/hashicorp-tools.yml

scope='origin'
# shellcheck source=origin/.scope
source ${scope}/.scope
export JENKINS_ADMIN_PASS=$ci_admin_pass
server_ip="$(echo ${ci_origin_json} | jq -r .ip)"
export JENKINS_ADDR=http://${server_ip}:${JENKINS_PORT}
ANSIBLE_TARGET='127.0.0.1' ./apl-wrapper.sh ansible/jenkins.yml
./jenkins-setup.sh

echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
JENKINS_BUILD_JOB=system-${scope}-job-seed ./jenkins-query.sh ./common/jobs/build-simple-job.groovy

origin_key=$(sudo su -s /bin/bash -c 'cat $HOME/.ssh/id_rsa.pub' jenkins)
for scope in factory prod; do
  echo "waiting for ${scope}-jenkins-deploy to finish..."
  chmod 600 .vagrant/machines/${scope}/virtualbox/private_key
  server_ip="$(echo ${ci_nodes_json} | jq --arg hostname "$scope" '.[] | select(.hostname==$hostname)' | jq -re .ip)"
  ssh $SSH_OPTS -i .vagrant/machines/${scope}/virtualbox/private_key ${server_ip} "if ! grep \"$origin_key\" \$HOME/.ssh/authorized_keys > /dev/null 2>&1; then mkdir -p \$HOME/.ssh; echo $origin_key >> \$HOME/.ssh/authorized_keys; fi"
  sudo su -s /bin/bash -c "ssh $SSH_OPTS $(whoami)@${server_ip}" jenkins
  JENKINS_SCOPE=${scope} ANSIBLE_TARGET=vagrant@${server_ip} JENKINS_BUILD_JOB=${scope}-jenkins-deploy ./jenkins-query.sh ./common/jobs/build-jenkins-deploy-job.groovy
done

server_nodes="$(echo ${server_nodes_json} | jq -re .[].ip | tr '\n' ',' | sed -e 's/,$/\n/')"
compute_nodes="$(echo ${compute_nodes_json} | jq -re .[].ip | tr '\n' ',' | sed -e 's/,$/\n/')"
all_nodes="${server_nodes},${compute_nodes}"

concat_json="$(echo ${server_nodes_json} | sed -e 's/]$/,/')$(echo ${compute_nodes_json} | sed -e 's/^\[//')"
echo $concat_json

nodes_count="$(echo $concat_json | jq -re .[].ip | wc -l)"
nodes_count=$((nodes_count - 1))

if [ "${nodes_count}" -le 0 ]; then
  echo "[error] nodes_count:${nodes_count}"
  exit 1
fi

key="$(cat /home/vagrant/.ssh/id_rsa.pub)"

for i in $(seq 0 $nodes_count); do
  hostname="$(echo $concat_json | jq -re .[$i].hostname)"
  ip="$(echo $concat_json | jq -re .[$i].ip)"
  chmod 600 .vagrant/machines/${hostname}/virtualbox/private_key
  ssh $SSH_OPTS -i .vagrant/machines/${hostname}/virtualbox/private_key ${ip} "if ! grep \"$key\" \$HOME/.ssh/authorized_keys > /dev/null 2>&1; then mkdir -p \$HOME/.ssh; echo $key >> \$HOME/.ssh/authorized_keys; fi"
  ssh $SSH_OPTS $ip
done

ANSIBLE_TARGET=${all_nodes} ANSIBLE_EXTRAVARS="{'serial_value':'100%'}" ./apl-wrapper.sh ansible/base.yml
ANSIBLE_TARGET=${all_nodes} ANSIBLE_EXTRAVARS="{'serial_value':'100%','authorized_keys':[{'user':'vagrant','file':'/home/vagrant/.ssh/id_rsa.pub'}]}" ./apl-wrapper.sh ansible/authorized-keys.yml

ANSIBLE_TARGET=${server_nodes} ANSIBLE_EXTRAVARS="{'serial_value':'100%','dns_servers':['/consul/127.0.0.1#8600','8.8.8.8','8.8.4.4'],'dnsmasq_supersede':true}" ./apl-wrapper.sh ansible/dnsmasq.yml
ANSIBLE_TARGET=${server_nodes} ANSIBLE_EXTRAVARS="{'serial_value':'100%','service_bind_ip':'{{ansible_host}}'}" ./apl-wrapper.sh ansible/consul-server.yml
ANSIBLE_TARGET=${server_nodes} ANSIBLE_EXTRAVARS="{'serial_value':'100%','service_bind_ip':'{{ansible_host}}'}" ./apl-wrapper.sh ansible/nomad-server.yml

for i in $(echo $server_nodes | tr ',' ' '); do
  if [ "$i" != "$server1_ip" ]; then
    ssh $SSH_OPTS $i "consul join ${server1_ip}"
    ssh $SSH_OPTS $i "NOMAD_ADDR=http://${i}:4646 nomad server-join ${server1_ip}"
  fi
done

ANSIBLE_TARGET=${server1_ip} ./apl-wrapper.sh ansible/vault-server.yml
VAULT_ADDR="http://${server1_ip}:8200" CONSUL_HTTP_ADDR="http://${server1_ip}:8500" ./extras/vault-demo.sh

ANSIBLE_TARGET=${compute_nodes} ANSIBLE_EXTRAVARS="{'serial_value':'100%','dns_servers':['/consul/${server1_ip}','/consul/${server2_ip}','8.8.8.8','8.8.4.4'],'dnsmasq_supersede':true}" ./apl-wrapper.sh ansible/dnsmasq.yml
ANSIBLE_TARGET=${compute_nodes} ANSIBLE_EXTRAVARS="{'serial_value':'100%','service_bind_ip': '{{ansible_host}}'}" ./apl-wrapper.sh ansible/consul-client.yml
ANSIBLE_TARGET=${compute_nodes} ANSIBLE_EXTRAVARS="{'serial_value':'100%','service_bind_ip': '{{ansible_host}}'}" ./apl-wrapper.sh ansible/nomad-client.yml
