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
        ansible --version
        jq --version
        curl -Ss http://127.0.0.1:8500/v1/status/leader
      '''
    }
    stage('prepare') {
      checkout([$class: 'GitSCM', 
        branches: [[name: '*/devel']], 
        doGenerateSubmoduleConfigurations: false, 
        submoduleCfg: [], 
        userRemoteConfigs: [[url: 'https://github.com/alexandruast/platform-inception.git']]])
      sh '''#!/usr/bin/env bash
      set -xeEo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      declare -a SSH_TARGETS
      for s in $(echo "${ANSIBLE_TARGET}" | tr ',' ' '); do
        if [[ *"@"* == "${s}" ]]; then
          SSH_TARGETS=("${SSH_TARGETS}" "${s}")
        else
          SSH_USER=$(echo "${ANSIBLE_EXTRAVARS}" | tr "'" '"' | jq -r .ansible_user)
          if [[ "${SSH_USER}" != "" ]]; then
            SSH_TARGETS=("${SSH_TARGETS}" "${SSH_USER}@${s}")
          else
            SSH_TARGETS=("${SSH_TARGETS}" "${s}")
          fi
        fi
      done
      curl -Ss --request PUT --data "$(IFS=$','; echo "${SSH_TARGETS[*]}")" http://127.0.0.1:8500/v1/kv/jenkins/pipeline_jenkins_deploy_ssh_targets
      '''
    }
    stage('provision') {
      sh '''#!/usr/bin/env bash
        set -xeEo pipefail
        trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
        SSH_TARGETS="$(curl -Ss http://127.0.0.1:8500/v1/kv/jenkins/pipeline_jenkins_deploy_ssh_targets?raw)"
        SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes'
        source ./${JENKINS_SCOPE}/.scope
        for s in $(echo "${SSH_TARGETS}" | tr ',' ' '); do
          ssh ${SSH_OPTS} ${s} "sudo yum -q -y install python libselinux-python"
        done
        ./apl-wrapper.sh ansible/target-${JENKINS_SCOPE}-jenkins.yml
      '''
    }
    stage('deploy') {
      sh '''#!/usr/bin/env bash
        set -xeEo pipefail
        trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
        SSH_TARGETS="$(curl -Ss http://127.0.0.1:8500/v1/kv/jenkins/pipeline_jenkins_deploy_ssh_targets?raw)"
        SSH_CONTROL_SOCKET="/tmp/ssh-control-socket-$(uuidgen)"
        trap 'for s in $(echo "${SSH_TARGETS}" | tr ',' ' '); do ssh -S "${SSH_CONTROL_SOCKET}" -O exit ${s}; done' EXIT
        SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ExitOnForwardFailure=yes'
        source ./${JENKINS_SCOPE}/.scope
        for s in $(echo "${SSH_TARGETS}" | tr ',' ' '); do
          tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
          ssh ${SSH_OPTS} -f -N -M -S "${SSH_CONTROL_SOCKET}" -L ${tunnel_port}:127.0.0.1:${JENKINS_PORT} ${s}
          JENKINS_ADDR=http://127.0.0.1:${tunnel_port} ./jenkins-setup.sh
          JENKINS_BUILD_JOB=system-${JENKINS_SCOPE}-job-seed JENKINS_ADDR=http://127.0.0.1:${tunnel_port} ./jenkins-query.sh ./common/jobs/build-simple-job.groovy
        done
      '''
    }
    stage('cleanup') {
      cleanWs()
    }
  }
}