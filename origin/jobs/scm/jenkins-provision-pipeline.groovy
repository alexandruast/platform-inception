node {
  wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs:[
    [password: "params.JENKINS_ADMIN_PASS", var: 'JENKINS_ADMIN_PASS']
  ]]) {
    stage('checkout') {
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
        trap 'ssh -S ssh-control-socket -O exit ${ANSIBLE_TARGET}' EXIT
        SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ExitOnForwardFailure=yes'
        ssh ${SSH_OPTS} ${ANSIBLE_TARGET} "sudo yum -q -y install python libselinux-python"
        source ./${PLATFORM_SCOPE}/.scope
        ./apl-wrapper.sh ansible/target-${PLATFORM_SCOPE}-jenkins.yml
        tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
        ssh ${SSH_OPTS} -f -N -M -S ssh-control-socket -L ${tunnel_port}:127.0.0.1:${JENKINS_PORT} ${ANSIBLE_TARGET}
        export JENKINS_ADDR=http://127.0.0.1:${tunnel_port}
        JENKINS_ENV_VAR_NAME="PLATFORM_SCOPE" \
          JENKINS_ENV_VAR_VALUE="${PLATFORM_SCOPE}" \
          ./jenkins-query.sh common/env-update.groovy
        ./jenkins-setup.sh
        JENKINS_BUILD_JOB=system-${PLATFORM_SCOPE}-job-seed JENKINS_ADDR=http://127.0.0.1:${tunnel_port} ./jenkins-query.sh ./common/jobs/build-simple-job.groovy
      '''
    }
    stage('cleanup') {
      cleanWs()
    }
  }
}