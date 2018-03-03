# platform-inception


#### TLDR
```
vagrant up
```

The first run will take aprox. 40 minutes on 7th gen core i5 with 8GB RAM.  
Subsequent runs will take much less:
* vagrant provision - 5 minutes
* vagrant up - 20 seconds


#### Description and Purpose - this is work in progress
This code brings up three Jenkins instances: Origin, Factory and Prod.  
Inception starts one Jenkins server, the Origin-Jenkins.  
Origin-Jenkins is then used to provision Factory-Jenkins and Prod-Jenkins, and it is only required at inception or when re-deploying those Jenkins instances.  
Because it has root access to Origin-Prod, it should be an air-gapped, single purpose machine and only started and connected to network when needed.  
Factory-Jenkins creates and manages all non-prod environments, where things get produced (Factory).  
Prod-Jenkins creates and manages all prod environments, where things get deployed to public (Prod).


#### Installation - 3x RHEL/compatible machines required

* Initial preparation - on your development machine
  * fork this github repo
  * clone your forked repo and replace all occurences of the upstream repo address (alexandruast/platform-inception) with your fork address
  ```
  git clone https://github.com/<your-github-id>/platform-inception.git
  find ./platform-inception -type f -exec sed -i 's|alexandruast/platform-inception|<your-github-id>/platform-inception|g' {} \;
  cd ./platform-inception
  git add . && git commit -m 'Updated git repo address' && git push
  ```

  * adjust scope files (./origin|factory|prod/.scope) to suit your needs:
  ```
  git add . && git commit -m 'Updated scope files' && git push
  ```

* Setup Origin-Jenkins - on the first RHEL machine
  * install prerequisites
  ```
  sudo yum -y install epel-release python libselinux-python
  sudo yum -y install ansible
  ```

  * clone your forked repo and run setup
  ```
  git clone https://github.com/<your-github-id>/platform-inception.git
  cd ./platform-inception
  source origin/.scope
  ANSIBLE_TARGET='127.0.0.1' ./apl-wrapper.sh ansible/jenkins.yml
  ./jenkins-setup.sh
  ```

* Setup Factory-Jenkins and Prod-Jenkins
  * from Origin-Jenkins, setup private key authentication:
  ```
  ssh-copy-id -i $HOME/.ssh/id_rsa <sudo_user>@<factory|prod-jenkins-ip>
  ```
  * From Origin-Jenkins UI, run the seeder job
    - system-origin-job-seed
  * From Origin-Jenkins UI, run deploy jobs to Factory-Jenkins and Prod-Jenkins:
    - factory-jenkins-deploy
    - prod-jenkins-deploy
  * From Factory-Jenkins UI, run the seeder job
    - system-factory-job-seed
  * From Prod-Jenkins UI, run the seeder job
    - system-prod-job-seed


#### Optional - use a VirtualBox VM for accelerated development and testing
* Download Oracle VirtualBox with Extensions Pack:
https://www.virtualbox.org/wiki/Downloads

* Download my base image VM - CentOS 6.9 from: https://1drv.ms/u/s!Apj7W8BZIxbIg7o46k34SnRkK6tflg

* Start VM in VirtualBox - if you want to create multiple VMs based on this one, you should make a full clone (with MAC address change) and use the clone for your workstation, otherwise you will run into UUID conflicts.

* The VM is configured to run with NAT networking, with the following ports forwarded:
  * 22   -> 127.0.2.1:22   SSH

* username:user, password:welcome1, hostname: 127.0.2.1, port:22
#### Installation

* Login via SSH to your newly created Linux VM

* Clone your fork in the VM
```
sudo yum -y install git
git clone https://github.com//<your-github-id>/platform-inception.git
cd ./platform-inception
```

* Install ansible
```
sudo yum -y install epel-release python libselinux-python
sudo yum -y install ansible
```

* Run workstation and jenkins playbooks
```
ANSIBLE_TARGET='127.0.0.1' ./apl-wrapper.sh ./ansible/workstation.yml
ANSIBLE_TARGET='127.0.0.1' JENKINS_PORT=8000 JENKINS_JAVA_OPTS="-Xmx500m -Djava.awt.headless=true -Djenkins.install.runSetupWizard=false" ./apl-wrapper.sh ./ansible/jenkins.yml
```

