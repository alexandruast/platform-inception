# platform-inception

#### TLDR
```
vagrant up sandbox
```

#### System requirements
* Vagrant - latest release
* 12GB RAM to run full platform: `vagrant up`
* 6GB RAM to run sandbox environment: `vagrant up sandbox`

The first run will take approx. 45 minutes on 7th gen core i5  
Subsequent runs will take much less:
* vagrant provision: 15 minutes
* vagrant up: 5 minutes

#### Description and Purpose - this is work in progress
This code brings up three Jenkins instances: Origin, Factory and Prod.  
Inception starts one Jenkins server, the Origin-Jenkins.  
Origin-Jenkins is then used to provision Factory-Jenkins and Prod-Jenkins, and it is only required at inception or when re-deploying Factory-Jenkins and Prod-Jenkins instances.  
Because it has root access to Origin-Prod, it should be an air-gapped, single purpose instance and only started and connected to network when needed.  
Factory-Jenkins creates and manages all non-prod environments, where things get produced (Factory).  
Prod-Jenkins creates and manages all prod environments, where things get deployed to public (Prod).  
Sandbox infrastructure (Nomad, Consul, Vault, Fabio) is provisioned from Factory-Jenkins.  

##### Done
* All environments are logically identical, starting with the developer's machine up to production
* 100% infrastructure as code, Jenkins included
* Automatic service onboarding - just fill in the source control repository, Jenkins does the rest - your service is ready for serving requests in Fabio
* Very safe deploy mechanism with automatic rollback support
* Every variable is stored in YAML files in source control
* Instantly run a full stack local platform with Vagrant, identical with live platform, same code that runs in production
* Instantly run a sandbox environment with Vagrant
* Nomad job files to mimic Kubernetes pods, for easy migration in the future if needed
* Infrastructure automation using Jenkins jobs - software updates, provisioning, periodic tasks
* Jenkins is not a critical service anymore (can be reprovisioned within minutes)
* CentOS7, Amazon Linux 7, RHEL 7 - all supported also in Vagrant

#### ToDo
* service autoscaling by business metrics with external witness, with infrastructure autoscaling support
* streamlined health, logging, metrics and monitoring dashboard
* request id map and breakdown by service and processing time
* chaos monkey
* build publish plugin - run build on prod-jenkins
* write groovy logic in job-dsl to retrieve all variables from consul
* hide sensitive info from console output
* store archives/backups

#### Changelog
support for multi-container pods is out of the box, using custom job/compose files  
Vagrant workstation support  
added tags support in pods, from yaml  
lnav removed, as it adds nothing of value for a tail/grep power user  
added command line arguments support in pods, from yaml  
added environment variables support in pods, from yaml  
decision to not implement consul/vault lockdown at this time, security needs per customer are very different  
td-agent-bit to listen on udp socket  
lnav ansible role  
fixed console stty issues in docker  
lnav added to fluentd container to have a minimal log inspect ability  
yaml-to-consul to delete only non-declared keys  
ansible builders for heavy lifting!  
moved all high-complexity embedded shell scripts out of groovy files  
added go sleep service  
mask docker files, nomad jobs, docker-compose files, dev selects runtime or place files in build dir to override  
parsing all jinja2 files in build directories  
moved variables from parametrized builds to environment using envinject  
added java echo service  
added ws-cleanup directories purge to hourly cron  
added hourly cron  
added nomad deploy checks  
added build_id and deploy_id logic  
will not build again if on the same commit_id  
all docker stuff is build with --no-cache option  
basic docker build also uses compose for better compatibility and collision avoidance  
decision to use multi step Dockerfile and not rely on Jenkins runtimes  
removed test step from pipelines, to be integrated in build  
automatically start jobs from vagrant: yaml-to-consul, import data, fluentd, fabio  
deployments can be referenced by commit id  
yaml-to-consul integration  
vault/consul kv integration  
env var groovy script added  
refactored vagrant always run scripts / vault-init  
sandbox mode added to vagrantfile - use one vm for sandbox environment  
jenkins jobs for vault token renew and secret update  
vault-init overhaul to better describe the approle flow  
basic_compose_pod can now deploy any basic docker-compose based pod, on any git url and branch  
removed "if->else" for pod builds, because it induced too much complexity  
replaced ansible-playbook for jinja2 templating with ad-hoc command  
replaced POD_VERSION with BUILD_TAG to better reflect what we're doing  
pods will build only if the git commit id changed, also changed the version string to be the short commit id  
created system cron daily maintenance jenkins job  - runs docker prune commands  
added fluentd pod for collecting logs  
refactored job-dsl job names and views  
added nomad service in dev mode to factory/prod jenkins to be able to properly validate jobs  
decision to have int/qa/prod environments, qa for performance testing  
decision to have the development/sandbox local in vagrant  
decision to bake the configuration into containers, reason is otherwise we will lose dev/prod parity because application configuration can be anything  
added build-docker-image script  
added td-agent-bit to target nodes  
added fabio docker container  
fixed binary not copied to destination if missing and already downloaded in ansible roles  
added api checks for consul/nomad/vault services in ansible roles - it should fail the playbook on first target if a service update fails  
one generic service_deploy_job_dsl.groovy with maps, instead of three  
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

#### Misc Stuff
For code coverage via Sonar, use the following in build.gradle:
```
plugins {
    id 'jacoco'
    id "org.sonarqube" version "2.6"
}

jacocoTestReport {
    reports {
        xml.enabled true
        html.enabled false
    }
}

check.dependsOn jacocoTestReport
```
then, use this command at build time:
```
gradle sonarqube -Dsonar.host.url=http://sonar.service.consul:9999/sonar -Dsonar.login=21b1b921bb73022cfefe9686edc66f959a7b57d4
```

To run a specific ansible playbook on workstation, use:
```
cd /vagrant && ANSIBLE_TARGET="127.0.0.1" ANSIBLE_EXTRAVARS="{'service_bind_ip':'192.168.169.254','service_network_interface':'enp0s8'}" ./apl-wrapper.sh ansible/debug.yml
```

