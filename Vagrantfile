# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV["LC_ALL"] = "en_US.UTF-8"

required_plugins = [ 'vagrant-triggers' ]

ci_admin_pass = "welcome1"
# box = "bento/centos-7.4"
# box = "moonphase/amazonlinux2"
box = "generic/rhel7"

ci_origin = {
  :hostname => "origin",
  :ip => "192.168.169.171",
  :box => box,
  :memory => 640,
  :cpus => 1
}

ci_nodes = [
  {
    :hostname => "factory",
    :ip => "192.168.169.172",
    :box => box,
    :memory => 800,
    :cpus => 2
  },
  {
    :hostname => "prod",
    :ip => "192.168.169.173",
    :box => box,
    :memory => 500,
    :cpus => 1
  }
]

server_nodes = [
  {
    :hostname => "server1",
    :ip => "192.168.169.181",
    :box => box,
    :memory => 500,
    :cpus => 1
  },
  {
    :hostname => "server2",
    :ip => "192.168.169.182",
    :box => box,
    :memory => 500,
    :cpus => 1
  }
]

compute_nodes = [
  {
    :hostname => "node1",
    :ip => "192.168.169.191",
    :box => box,
    :memory => 640,
    :cpus => 2
  }
]

missing_plugins = required_plugins.reject { |p| Vagrant.has_plugin?(p) }
unless missing_plugins.empty?
  system "vagrant plugin install #{missing_plugins.join(' ')}"
  puts "Installed new Vagrant plugins. Please re-run your last command!"
  exit 1
end

if box.include? "rhel"
  rhel_subscription_username = 'none'
  rhel_subscription_password = 'none'
  if ARGV[0] == "up" or ARGV[0] == "provision"
    puts "Red Hat Enterprise Linux requires RHN subscription."
    print "Press ENTER within 3 seconds to enter credentials."

    timeout_seconds = 3

    loop_a = Thread.new do
      Thread.current["key_pressed"] = false
      STDIN.noecho(&:gets).chomp
      Thread.current["key_pressed"] = true
    end

    loop_b = Thread.new do
      start_time = Time.now.to_f.to_int
      current_time = start_time
      progress_time = start_time
      while current_time - start_time < timeout_seconds do
        break if !loop_a.alive?
        current_time = Time.now.to_f.to_int
        if progress_time != current_time
          print '.'
          progress_time = current_time
        end
      end
      print "\n"
    end

    loop_b.join
    loop_a.exit
    loop_a.join

    if loop_a["key_pressed"]
      print "RHN username:"
      rhel_subscription_username = STDIN.gets.chomp
      print "RHN passsword:"
      rhel_subscription_password = STDIN.gets.chomp
    end
  end
end

always_origin = <<SCRIPT
#!/usr/bin/env bash
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
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

bootstrap = <<SCRIPT
#!/usr/bin/env bash
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
find /home/vagrant/provision -type f -name '*.sh' -exec chmod +x {} \\;
if which yum; then
  if which subscription-manager; then
    if ! sudo subscription-manager status 2>/dev/null; then
      sudo subscription-manager register --username=#{rhel_subscription_username.strip} --password=#{rhel_subscription_password.strip} --auto-attach
      sudo yum-config-manager --disable rhel-7-server-rt-beta-rpms
    fi
  fi
  sudo yum -q -y install python libselinux-python
elif which apt-get; then
  sudo apt-get update
  sudo apt-get -qq -y install python
else
  exit 1
fi
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
      node.vm.provision "shell", inline: bootstrap, privileged: false
      node.trigger.before :destroy do
        begin
          run_remote "if which subscription-manager; then sudo subscription-manager unregister; fi"
        rescue
          puts "If something went wrong, please remove the vm manually from https://access.redhat.com/management/subscriptions"
        end
      end
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
      node.vm.provision "shell", inline: bootstrap, privileged: false
      node.trigger.before :destroy do
        begin
          run_remote "if which subscription-manager; then sudo subscription-manager unregister; fi"
        rescue
          puts "If something went wrong, please remove the vm manually from https://access.redhat.com/management/subscriptions"
        end
      end
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
      node.vm.provision "shell", inline: bootstrap, privileged: false
      node.trigger.before :destroy do
        begin
          run_remote "if which subscription-manager; then sudo subscription-manager unregister; fi"
        rescue
          puts "If something went wrong, please remove the vm manually from https://access.redhat.com/management/subscriptions"
        end
      end
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
    node.vm.provision "shell", inline: bootstrap, privileged: false
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
    node.trigger.before :destroy do
      begin
        run_remote "if which subscription-manager; then sudo subscription-manager unregister; fi"
      rescue
        puts "If something went wrong, please remove the vm manually from https://access.redhat.com/management/subscriptions"
      end
    end
  end
end

