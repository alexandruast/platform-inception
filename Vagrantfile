# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV["LC_ALL"] = "en_US.UTF-8"

required_plugins = [ 'vagrant-triggers' ]

ci_admin_pass = "welcome1"
box = "bento/centos-7.4"
# box = "moonphase/amazonlinux2"
# box = "generic/rhel7"

ci_origin = {
  :hostname => "origin",
  :ip => "192.168.169.171",
  :box => box,
  :memory => 640,
  :cpus => 1
}

ci_factory = {
  :hostname => "factory",
  :ip => "192.168.169.172",
  :box => box,
  :memory => 800,
  :cpus => 2
}

ci_prod = {
  :hostname => "prod",
  :ip => "192.168.169.173",
  :box => box,
  :memory => 500,
  :cpus => 1
}

nomad_servers = [
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

rhel_subscription_username = 'none'
rhel_subscription_password = 'none'

if box.include? "rhel"
  if ARGV[0] == "up" or ARGV[0] == "provision"
    puts "Red Hat Enterprise Linux requires RHN subscription."
    print "Press ENTER within 5 seconds to enter credentials."

    timeout_seconds = 5

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

bootstrap = <<SCRIPT
#!/usr/bin/env bash
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
if [ -d "/home/vagrant/provision" ];then
  find /home/vagrant/provision -type f -name '*.sh' -exec chmod +x {} \\;
fi
if which subscription-manager; then
  if ! sudo subscription-manager status 2>/dev/null; then
    sudo subscription-manager register --username=#{rhel_subscription_username.strip} --password=#{rhel_subscription_password.strip} --auto-attach
    sudo yum-config-manager --disable rhel-7-server-rt-beta-rpms
  fi
fi
sudo yum -q -y install python libselinux-python
SCRIPT

Vagrant.configure(2) do |config|
  
  [ci_factory,ci_prod].each do |machine|
    config.vm.define machine[:hostname] do |node|
      node.vm.box = machine[:box]
      node.vm.hostname = machine[:hostname]
      node.vm.provider "virtualbox" do |vb|
        vb.linked_clone = true
        vb.memory = machine[:memory]
        vb.cpus = machine[:cpus]
      end  
      node.vm.network "private_network", ip: machine[:ip]
      node.vm.provision "shell", path: "./extras/sandbox-ssh-key.sh", privileged: false
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
  
  nomad_servers.each do |machine|
    config.vm.define machine[:hostname] do |node|
      node.vm.box = machine[:box]
      node.vm.hostname = machine[:hostname]
      node.vm.provider "virtualbox" do |vb|
        vb.linked_clone = true
        vb.memory = machine[:memory]
        vb.cpus = machine[:cpus]
      end  
      node.vm.network "private_network", ip: machine[:ip]
      node.vm.provision "shell", path: "./extras/sandbox-ssh-key.sh", privileged: false
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
      node.vm.provision "shell", path: "./extras/sandbox-ssh-key.sh", privileged: false
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
    node.vm.provision "shell", path: "./extras/sandbox-ssh-key.sh", privileged: false
    node.vm.provision "shell", inline: bootstrap, privileged: false
    node.vm.provision "shell" do |s|
      s.path = "./extras/bootstrap-origin.sh"
      s.privileged = false
      s.args = [
        ci_admin_pass,
        ci_origin.to_json.to_s,
        ci_factory.to_json.to_s,
        ci_prod.to_json.to_s,
        nomad_servers.to_json.to_s,
        compute_nodes.to_json.to_s
      ]
    end
    node.vm.provision "shell", run: "always" do |s|
      s.path = "./extras/always-origin.sh"
      s.privileged = false
      s.args = [
        ci_admin_pass,
        ci_origin.to_json.to_s,
        ci_factory.to_json.to_s,
        ci_prod.to_json.to_s,
        nomad_servers.to_json.to_s
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

