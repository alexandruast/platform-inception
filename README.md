# platform-inception

#### TLDR
```
vagrant up
```

#### Minimum system requirements
* Vagrant - latest release
* 8GB RAM

The first run will take approx. 30 minutes on 7th gen core i5  
Subsequent runs will take much less:
* vagrant provision: 5 minutes
* vagrant up: 30 seconds


#### Description and Purpose - this is work in progress
This code brings up three Jenkins instances: Origin, Factory and Prod.  
Inception starts one Jenkins server, the Origin-Jenkins.  
Origin-Jenkins is then used to provision Factory-Jenkins and Prod-Jenkins, and it is only required at inception or when re-deploying Factory-Jenkins and Prod-Jenkins instances.  
Because it has root access to Origin-Prod, it should be an air-gapped, single purpose instance and only started and connected to network when needed.  
Factory-Jenkins creates and manages all non-prod environments, where things get produced (Factory).  
Prod-Jenkins creates and manages all prod environments, where things get deployed to public (Prod).  
Sandbox infrastructure (Nomad, Consul, Vault, Fabio) is provisioned from Factory-Jenkins.

#### Changelog
moved from triggers plugin to built-in triggers  
added jenkins job for consul server  
fixed service start in ansible playbooks for services  
start a pipeline on a server, backup, destroy server, resume on newly created one  
refactored scope directories, moved common roles out  
PERFORMANCE_OPTIMIZED mode set for pipelines  
jenkins job for os updates  
made vault ha with two servers, to be as close as possible with production  
primary consul dns servers in factory/prod jenkins dnsmasq  
refactored vault demo  
implemented jenkins backup/restore at the instance level  
force_setup flag saves 2 minutes on each run, on average, but breaks idempotency - added variable into each target playbook so it runs all roles by default, but can be overriden (when in use by vagrant, in this scenario)  
cached all downloads locally with precopy, now updates work properly  
simplified pipelines: jenkins deploy restricted to one target  
ansible now handles upgrades to all components  
added swap playbook to all targets, again - because it won't work otherwise with distros that have zero swap (amazon linux)  
fix for ansible dir diff - force setup  
removed base-minimal role, as the main base role makes it redundant, it has too many problems with dependencies  
removed install python and libselinux-python from vagrantfile, moved to provision script and jenkins job scripts  
added ssh install python and libselinux-python to all scm machine deploy jobs  
moved to official epel-release install via yum instead of .repo file  
added dnsmasq to all targets, and control behavior from playbook variables  
selectable java jre between openjdk and oracle  
force_setup set to true if the ansible dir changed, even if previously set to false  
local consul in dev mode as ephemeral key value store in jenkins  
accelerated provisioning by using setup_completed facts  

#### Misc
```
ANSIBLE_JUMPHOST=jumper@bastion.example.com \
ANSIBLE_TARGET=user@10.241.2.10 \
./apl-wrapper.sh ansible/debug.yml

ANSIBLE_TARGET=vagrant@192.168.169.181,vagrant@192.168.169.182 \
ANSIBLE_EXTRAVARS="{'start_services':['consul','nomad']}" \
./apl-wrapper.sh ansible/os-update.yml
docker build --tag platformdemo/images:fluentd-devel-20180320 --force-rm --pull --no-cache ./
docker run --rm -it -d -p 24224:24224 -p 5140:5140 platformdemo/images:fluentd-devel-20180320
```

