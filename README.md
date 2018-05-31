# platform-inception

#### TLDR
```
vagrant up sandbox
```

#### System requirements
* Vagrant - latest release
* Full platform - 16GB RAM
* Sandbox environment - 8GB RAM

The first run will take approx. 45 minutes on 7th gen core i5  
Subsequent runs will take much less:
* vagrant provision: 10 minutes
* vagrant up: 2 minutes

#### Description and Purpose - this is work in progress
This code brings up three Jenkins instances: Origin, Factory and Prod.  
Inception starts one Jenkins server, the Origin-Jenkins.  
Origin-Jenkins is then used to provision Factory-Jenkins and Prod-Jenkins, and it is only required at inception or when re-deploying Factory-Jenkins and Prod-Jenkins instances.  
Because it has root access to Origin-Prod, it should be an air-gapped, single purpose instance and only started and connected to network when needed.  
Factory-Jenkins creates and manages all non-prod environments, where things get produced (Factory).  
Prod-Jenkins creates and manages all prod environments, where things get deployed to public (Prod).  
Sandbox infrastructure (Nomad, Consul, Vault, Fabio) is provisioned from Factory-Jenkins.  

#### ToDo

##### Improvements
* write groovy logic in job-dsl to retrieve all variables from consul
* fluentd to listen on udp socket
* authenticate consul with vault for write operations
* hide sensitive info from console output
* store archives/backups

##### Features
* platform/conf to have a structure to permit multi-tenancy
* streamlined CI tool to trigger jobs per tenant
* streamlined health, logging, metrics and monitoring dashboard
* artifact repository
* build publish plugin - run build on prod-jenkins
* docker-enforcer and vulnerability assessment for docker images/files

#### Changelog
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
