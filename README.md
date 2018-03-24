# platform-inception

#### TLDR
```
vagrant up
```

#### Minimum system requirements
* Vagrant - latest release
* 8GB RAM

The first run will take approx. 60 minutes on 7th gen core i5  
Subsequent runs will take much less:
* vagrant provision: 5 to 10 minutes
* vagrant up: 20 seconds


#### Description and Purpose - this is work in progress
This code brings up three Jenkins instances: Origin, Factory and Prod.  
Inception starts one Jenkins server, the Origin-Jenkins.  
Origin-Jenkins is then used to provision Factory-Jenkins and Prod-Jenkins, and it is only required at inception or when re-deploying Factory-Jenkins and Prod-Jenkins instances.  
Because it has root access to Origin-Prod, it should be an air-gapped, single purpose instance and only started and connected to network when needed.  
Factory-Jenkins creates and manages all non-prod environments, where things get produced (Factory).  
Prod-Jenkins creates and manages all prod environments, where things get deployed to public (Prod).  
Sandbox infrastructure is provisioned via ansible from origin shell.

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

