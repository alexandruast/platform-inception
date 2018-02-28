# -*- mode: ruby -*-
# vi: set ft=ruby :
ENV["LC_ALL"] = "en_US.UTF-8"

$box="bento/centos-6.9"
$memory = "1000"
$cpus = 1
$origin_hostname = "origin-jenkins"
$origin_ip = "192.168.169.170"
$factory_hostname = "factory-jenkins"
$factory_ip = "192.168.169.171"
$prod_hostname = "factory-jenkins"
$prod_ip = "192.168.169.172"
$provision_dir = "/tmp/tmp.H7NVqJGC2q"
$jenkins_admin_pass = "welcome1"

$origin_bootstrap = <<SCRIPT
#!/usr/bin/env bash
set -eEo pipefail
trap 'echo "[error] exit code $? running $(eval echo $BASH_COMMAND)"' ERR
SSH_OPTS='-o LogLevel=quiet -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'

provision_dir=$1
jenkins_admin_pass=$2
origin_ip=$3
factory_ip=$4
prod_ip=$5

cd $provision_dir
chmod +x ./*.sh

sudo yum -q -y install epel-release python libselinux-python
sudo yum -q -y install ansible

export JENKINS_ADMIN_PASS=$jenkins_admin_pass

scope='origin'
ip_var="${scope}_ip"
source ${scope}/.scope
export ANSIBLE_TARGET='127.0.0.1'
./apl-wrapper.sh ansible/jenkins-${scope}.yml

./jenkins-setup.sh
./jenkins-query.sh common/is-online.groovy
echo "${scope}-jenkins is online: http://${!ip_var}:${JENKINS_PORT} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"

JENKINS_BUILD_JOB=system-${scope}-job-seed ./jenkins-query.sh ./common/jobs/build-simple-job.groovy

opk=$(ssh-keygen -y -f $HOME/.ssh/id_rsa)
for scope in factory prod; do
  echo "waiting for ${scope}-jenkins-deploy to finish..."
  chmod 600 .vagrant/machines/${scope}/virtualbox/private_key
  ip_var="${scope}_ip"
  ssh $SSH_OPTS -i .vagrant/machines/${scope}/virtualbox/private_key ${!ip_var} "if ! grep \'$opk\' \$HOME/.ssh/authorized_keys >> /dev/null; then echo "$opk" >> \$HOME/.ssh/authorized_keys; fi"
  ssh $SSH_OPTS ${!ip_var} "whoami" >/dev/null
  JENKINS_SCOPE=${scope} ANSIBLE_TARGET=vagrant@${!ip_var} JENKINS_BUILD_JOB=${scope}-jenkins-deploy ./jenkins-query.sh ./common/jobs/build-jenkins-deploy-job.groovy
done
SCRIPT

$origin_always = <<SCRIPT
#!/usr/bin/env bash
set -eEo pipefail
trap 'echo "[error] exit code $? running $(eval echo $BASH_COMMAND)"' ERR
SSH_OPTS='-o LogLevel=quiet -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'

provision_dir=$1
jenkins_admin_pass=$2
origin_ip=$3
factory_ip=$4
prod_ip=$5

cd $provision_dir

for scope in origin factory prod; do
  export JENKINS_NULL='null'
  for v in $(env | grep '^JENKINS_' | cut -f1 -d'='); do unset $v; done
  source ${scope}/.scope
  export JENKINS_ADMIN_PASS=$jenkins_admin_pass
  ip_var="${scope}_ip"
  export JENKINS_ADDR=http://${!ip_var}:${JENKINS_PORT}
  ./jenkins-query.sh common/is-online.groovy
  echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
done
SCRIPT

Vagrant.configure(2) do |config|
  config.vm.define "factory" do |node|
    node.vm.box = $box
    node.vm.hostname = $factory_hostname
    node.vm.provider "virtualbox" do |vb|
        vb.memory = $memory
        vb.cpus = $cpus
    end  
    node.vm.network "private_network", ip: $factory_ip
  end
  
  config.vm.define "prod" do |node|
    node.vm.box = $box
    node.vm.hostname = $prod_hostname
    node.vm.provider "virtualbox" do |vb|
        vb.memory = $memory
        vb.cpus = $cpus
    end  
    node.vm.network "private_network", ip: $prod_ip
  end
  
  config.vm.define "origin" do |node|
    node.vm.box = $box
    node.vm.hostname = $origin_hostname
    
    node.vm.provider "virtualbox" do |vb|
        vb.memory = $memory
        vb.cpus = $cpus
    end
    
    node.vm.network "private_network", ip: $origin_ip
    node.vm.provision "shell", inline: "rm -fr $1", privileged: false, args: $provision_dir
    node.vm.provision "file", source: "./", destination: $provision_dir
    
    node.vm.provision "shell" do |s|
      s.inline = $origin_bootstrap
      s.privileged = false
      s.args = [ 
        $provision_dir,
        $jenkins_admin_pass,
        $origin_ip,
        $factory_ip,
        $prod_ip
      ]
    end
    
    node.vm.provision "shell", run: "always" do |s|
      s.inline = $origin_always
      s.privileged = false
      s.args = [
        $provision_dir,
        $jenkins_admin_pass,
        $origin_ip,
        $factory_ip,
        $prod_ip
      ]
    end
  end
end
