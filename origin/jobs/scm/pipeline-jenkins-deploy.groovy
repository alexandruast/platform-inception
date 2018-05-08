node {
  wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs:[
    [password: "params.JENKINS_ADMIN_PASS", var: 'JENKINS_ADMIN_PASS']
  ]]) {
    stage('validate') {
      sh '''
        [ x"${JENKINS_ADMIN_PASS}" != 'x' ]
        [ x"${ANSIBLE_TARGET}" != 'x' ]
        [ x"${JENKINS_SCOPE}" != 'x' ]
        echo "ANSIBLE_EXTRAVARS=${ANSIBLE_EXTRAVARS}"
        if [[ *"@"* == "${ANSIBLE_TARGET}" ]]; then
          SSH_TARGET="${ANSIBLE_TARGET}"
        else
          SSH_USER=$(echo "${ANSIBLE_EXTRAVARS}" | tr "'" '"' | jq -r .ansible_user)
          if [[ "${SSH_USER}" != "" ]]; then
            SSH_TARGET="${SSH_USER}@${ANSIBLE_TARGET}"
          else
            SSH_TARGET="${ANSIBLE_TARGET}"
          fi
        fi
        pwd
        echo "SSH_TARGET=${SSH_TARGET}" >> .jenkins_env
        ls -la
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
        source .jenkins_env
        SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'
        source ./${JENKINS_SCOPE}/.scope
        ssh $SSH_OPTS ${SSH_TARGET} "sudo yum -q -y install python libselinux-python"
        ./apl-wrapper.sh ansible/target-${JENKINS_SCOPE}-jenkins.yml
      '''
    }
    stage('deploy') {
      sh '''#!/usr/bin/env bash
        set -xeEo pipefail
        trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
        source .jenkins_env
        SSH_CONTROL_SOCKET="/tmp/ssh-control-socket-$(uuidgen)"
        trap 'ssh -S "${SSH_CONTROL_SOCKET}" -O exit ${SSH_TARGET}' EXIT
        SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ExitOnForwardFailure=yes'
        source ./${JENKINS_SCOPE}/.scope
        tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
        ssh $SSH_OPTS -f -N -M -S "${SSH_CONTROL_SOCKET}" -L ${tunnel_port}:127.0.0.1:${JENKINS_PORT} ${SSH_TARGET}
        JENKINS_ADDR=http://127.0.0.1:${tunnel_port} ./jenkins-setup.sh
        JENKINS_BUILD_JOB=system-${JENKINS_SCOPE}-job-seed JENKINS_ADDR=http://127.0.0.1:${tunnel_port} ./jenkins-query.sh ./common/jobs/build-simple-job.groovy
      '''
    }
    stage('cleanup') {
      cleanWs()
    }
  }
}