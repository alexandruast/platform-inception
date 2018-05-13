node {
  wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs:[
    [password: "params.JENKINS_ADMIN_PASS", var: 'JENKINS_ADMIN_PASS']
  ]]) {
    stage('validation') {
      sh '''
        [ x"${JENKINS_ADMIN_PASS}" != 'x' ]
        [ x"${ANSIBLE_TARGET}" != 'x' ]
        [  *","* != "${ANSIBLE_TARGET}" ]
        [ x"${JENKINS_SCOPE}" != 'x' ]
        echo "ANSIBLE_EXTRAVARS=${ANSIBLE_EXTRAVARS}"
        ansible --version
        jq --version
      '''
    }
    stage('preparation') {
      checkout([$class: 'GitSCM', 
        branches: [[name: '*/devel']], 
        doGenerateSubmoduleConfigurations: false, 
        submoduleCfg: [], 
        userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
    }
    stage('deploy') {
      sh '''#!/usr/bin/env bash
        set -xeEo pipefail
        trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
        trap 'ssh -S ssh-control-socket -O exit ${ANSIBLE_TARGET}' EXIT
        SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ExitOnForwardFailure=yes'
        ssh ${SSH_OPTS} ${ANSIBLE_TARGET} "sudo yum -q -y install python libselinux-python"
        source ./${JENKINS_SCOPE}/.scope
        ./apl-wrapper.sh ansible/target-${JENKINS_SCOPE}-jenkins.yml
        tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
        ssh ${SSH_OPTS} -f -N -M -S ssh-control-socket -L ${tunnel_port}:127.0.0.1:${JENKINS_PORT} ${ANSIBLE_TARGET}
        JENKINS_ADDR=http://127.0.0.1:${tunnel_port} ./jenkins-setup.sh
        JENKINS_BUILD_JOB=system-${JENKINS_SCOPE}-job-seed JENKINS_ADDR=http://127.0.0.1:${tunnel_port} ./jenkins-query.sh ./common/jobs/build-simple-job.groovy
      '''
    }
    stage('cleanup') {
      cleanWs()
    }
  }
}