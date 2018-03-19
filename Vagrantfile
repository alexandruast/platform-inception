# -*- mode: ruby -*-
# vi: set ft=ruby :
ENV["LC_ALL"] = "en_US.UTF-8"

ci_admin_pass = "welcome1"

ci_origin = {
  :hostname => "origin",
  :ip => "192.168.169.171",
  :box => "bento/centos-7.4",
  :memory => 640,
  :cpus => 1
}

ci_nodes = [
  {
    :hostname => "factory",
    :ip => "192.168.169.172",
    :box => "bento/centos-7.4",
    :memory => 800,
    :cpus => 2
  },
  {
    :hostname => "prod",
    :ip => "192.168.169.173",
    :box => "bento/centos-7.4",
    :memory => 500,
    :cpus => 1
  }
]

server_nodes = [
  {
    :hostname => "server1",
    :ip => "192.168.169.181",
    :box => "bento/centos-7.4",
    :memory => 500,
    :cpus => 1
  },
  {
    :hostname => "server2",
    :ip => "192.168.169.182",
    :box => "bento/centos-7.4",
    :memory => 500,
    :cpus => 1
  }
]

compute_nodes = [
  {
    :hostname => "node1",
    :ip => "192.168.169.191",
    :box => "bento/centos-7.4",
    :memory => 640,
    :cpus => 2
  }
]

always_origin = <<SCRIPT
#!/usr/bin/env bash
set -eEo pipefail
trap '{ RC=$?; echo "[error] exit code $RC running $(eval echo $BASH_COMMAND)"; exit $RC; }'  ERR
ci_admin_pass=$1
ci_origin_json=$2
ci_nodes_json=$3
server_nodes_json=$4
compute_nodes_json=$5
cd /home/vagrant/provision
concat_json="$(echo ${ci_nodes_json} | sed -e 's/]$/,/')${ci_origin_json}]"
for scope in origin factory prod; do
  export JENKINS_NULL='null'
  for v in $(env | grep '^JENKINS_' | cut -f1 -d'='); do unset $v; done
  source ${scope}/.scope
  export JENKINS_ADMIN_PASS=$ci_admin_pass
  server_ip="$(echo ${concat_json} | jq --arg hostname "$scope" '.[] | select(.hostname==$hostname)' | jq -re .ip)"
  export JENKINS_ADDR=http://${server_ip}:${JENKINS_PORT}
  ./jenkins-query.sh common/is-online.groovy
  echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
done
server1_ip="$(echo ${server_nodes_json} | jq -r .[0].ip)"
server2_ip="$(echo ${server_nodes_json} | jq -r .[1].ip)"
curl --silent -X PUT "http://${server1_ip}:4646/v1/system/gc"
echo "Consul UI is available at http://${server1_ip}:8500"
echo "Nomad UI is available at http://${server1_ip}:4646"
echo "Vault is available at http://${server1_ip}:8200"
SCRIPT

bootstrap_centos7 = <<SCRIPT
#!/usr/bin/env bash
set -eEo pipefail
trap '{ RC=$?; echo "[error] exit code $RC running $(eval echo $BASH_COMMAND)"; exit $RC; }'  ERR
find /home/vagrant/provision -type f -name '*.sh' -exec chmod +x {} \\;
sudo yum -q -y install python libselinux-python
SCRIPT

Vagrant.configure(2) do |config|
  
  ci_nodes.each do |machine|
    config.vm.define machine[:hostname] do |node|
      node.vm.box = machine[:box]
      node.vm.hostname = machine[:hostname]
      node.vm.provider "virtualbox" do |vb|
        vb.linked_clone = true
        vb.memory = machine[:memory]
        vb.cpus = machine[:cpus]
      end  
      node.vm.network "private_network", ip: machine[:ip]
      node.vm.provision "shell", inline: "rm -fr /home/vagrant/provision", privileged: false
      node.vm.provision "file", source: "./", destination: "/home/vagrant/provision"
      node.vm.provision "shell", inline: bootstrap_centos7, privileged: false
    end
  end
  
  server_nodes.each do |machine|
    config.vm.define machine[:hostname] do |node|
      node.vm.box = machine[:box]
      node.vm.hostname = machine[:hostname]
      node.vm.provider "virtualbox" do |vb|
        vb.linked_clone = true
        vb.memory = machine[:memory]
        vb.cpus = machine[:cpus]
      end  
      node.vm.network "private_network", ip: machine[:ip]
      node.vm.provision "shell", inline: "rm -fr /home/vagrant/provision", privileged: false
      node.vm.provision "file", source: "./", destination: "/home/vagrant/provision"
      node.vm.provision "shell", inline: bootstrap_centos7, privileged: false
    end
  end
  
  compute_nodes.each do |machine|
    config.vm.define machine[:hostname] do |node|
      node.vm.box = machine[:box]
      node.vm.hostname = machine[:hostname]
      node.vm.provider "virtualbox" do |vb|
        vb.linked_clone = true
        vb.memory = machine[:memory]
        vb.cpus = machine[:cpus]
      end  
      node.vm.network "private_network", ip: machine[:ip]
      node.vm.provision "shell", inline: "rm -fr /home/vagrant/provision", privileged: false
      node.vm.provision "file", source: "./", destination: "/home/vagrant/provision"
      node.vm.provision "shell", inline: bootstrap_centos7, privileged: false
    end
  end
  
  config.vm.define "origin" do |node|
    node.vm.box = ci_origin[:box]
    node.vm.hostname = ci_origin[:hostname]
    node.vm.provider "virtualbox" do |vb|
        vb.linked_clone = true
        vb.memory = ci_origin[:memory]
        vb.cpus = ci_origin[:cpus]
    end
    node.vm.network "private_network", ip: ci_origin[:ip]
    node.vm.provision "shell", inline: "rm -fr /home/vagrant/provision", privileged: false
    node.vm.provision "file", source: "./", destination: "/home/vagrant/provision"
    node.vm.provision "shell", inline: bootstrap_centos7, privileged: false
    node.vm.provision "shell" do |s|
      s.path = "./extras/bootstrap-origin.sh"
      s.privileged = false
      s.args = [
        ci_admin_pass,
        ci_origin.to_json.to_s,
        ci_nodes.to_json.to_s,
        server_nodes.to_json.to_s,
        compute_nodes.to_json.to_s
      ]
    end
    node.vm.provision "shell", run: "always" do |s|
      s.inline = always_origin
      s.privileged = false
      s.args = [
        ci_admin_pass,
        ci_origin.to_json.to_s,
        ci_nodes.to_json.to_s,
        server_nodes.to_json.to_s,
        compute_nodes.to_json.to_s
      ]
    end
  end
end

