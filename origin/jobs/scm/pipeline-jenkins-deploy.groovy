node {
  wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs:[
    [password: "params.JENKINS_ADMIN_PASS", var: 'JENKINS_ADMIN_PASS']
  ]]) {
    stage('validate') {
      sh '''
        [ x"$JENKINS_ADMIN_PASS" != 'x' ]
        [ x"$JENKINS_SCOPE" != 'x' ]
      '''
    }
    stage('prepare') {
      checkout([$class: 'GitSCM', 
        branches: [[name: '*/devel']], 
        doGenerateSubmoduleConfigurations: false, 
        submoduleCfg: [], 
        userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
    }
    stage('provision') {
      sh '''#!/usr/bin/env bash
        set -xeEo pipefail
        trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
        SSH_OPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'
        source ./$JENKINS_SCOPE/.scope
        ssh $SSH_OPTS $ANSIBLE_TARGET "sudo yum -q -y install python libselinux-python"
        ./apl-wrapper.sh ansible/jenkins.yml
      '''
    }
    stage('deploy') {
      sh '''#!/usr/bin/env bash
        set -xeEo pipefail
        trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
        SSH_OPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ExitOnForwardFailure=yes'
        source ./$JENKINS_SCOPE/.scope
        tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
        ssh $SSH_OPTS -f -N -M -S ssh-control-socket -L ${tunnel_port}:127.0.0.1:${JENKINS_PORT} ${ANSIBLE_TARGET}
        JENKINS_ADDR=http://127.0.0.1:${tunnel_port} ./jenkins-setup.sh
        ssh -S ssh-control-socket -O exit ${ANSIBLE_TARGET}
      '''
    }
    stage('cleanup') {
      cleanWs()
    }
  }
}