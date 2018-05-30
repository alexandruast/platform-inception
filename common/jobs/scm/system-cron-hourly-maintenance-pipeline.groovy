node {
  stage('maintenance') {
    sh'''#!/usr/bin/env bash
      set -xeEuo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      find ${JENKINS_HOME}/workspace -maxdepth 1 -name "*_ws-cleanup_*" -type d -mmin +30 -exec rm -fr {} +
    '''
  }
}
