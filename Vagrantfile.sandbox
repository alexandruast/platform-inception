# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV["LC_ALL"] = "en_US.UTF-8"
ENV["VAGRANT_DISABLE_VBOXSYMLINKCREATE"] = "1"

required_plugins = []

ci_admin_pass = "welcome1"

box = "bento/centos-7.4"
# box = "moonphase/amazonlinux2"
# box = "xianlin/rhel-7"

ci_factory = {
  :hostname => "factory",
  :ip => "192.168.169.172",
  :box => box,
  :memory => 3600,
  :cpus => 2
}

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
    sudo subscription-manager register --username=#{rhel_subscription_username.strip} --password=#{rhel_subscription_password.strip} --auto-attach --force
  fi
fi
SCRIPT

Vagrant.configure(2) do |config|
  config.vm.define "factory" do |node|
    node.vm.box = ci_factory[:box]
    node.vm.hostname = ci_factory[:hostname]
    node.vm.provider "virtualbox" do |vb|
        vb.linked_clone = true
        vb.memory = ci_factory[:memory]
        vb.cpus = ci_factory[:cpus]
    end
    node.vm.network "private_network", ip: ci_factory[:ip]
    node.vm.provision "shell", path: "./extras/sandbox-ssh-key.sh", privileged: false
    node.vm.provision "shell", inline: bootstrap, privileged: false
    node.vm.provision "shell" do |s|
      s.path = "./extras/bootstrap-sandbox.sh"
      s.privileged = false
      s.args = [
        ci_admin_pass
      ]
    end
    node.vm.provision "shell", run: "always" do |s|
      s.path = "./extras/always-sandbox.sh"
      s.privileged = false
      s.args = [
        ci_admin_pass,
        ci_factory.to_json.to_s
      ]
    end
    node.trigger.before :destroy do |trigger|
      trigger.on_error = :continue
      begin
        trigger.run_remote = { inline: "if which subscription-manager; then sudo subscription-manager unregister; fi" } if box.include? "rhel"
      rescue
        puts "If something went wrong, please remove the vm manually from https://access.redhat.com/management/subscriptions"
      end
    end
  end
end

