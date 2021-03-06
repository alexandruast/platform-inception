node {
  stage('maintenance') {
    sh'''#!/usr/bin/env bash
      set -xeEuo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      if which docker; then
        docker system prune -f
        docker volume prune -f
        docker image prune -a -f
      fi
    '''
  }
}
