#!/usr/bin/env bash
# Warning: this script is NOT POSIX compliant, and was never meant to be!
set -eEuo pipefail
trap 'echo "[error] exit code $? running $(eval echo $BASH_COMMAND)"' ERR

readonly JENKINS_SCRIPT_RUN_WRAPPER='./jenkins-query.sh'
declare -a cmd_args

usage() {
  cat << EOF
    Usage: ${0##*/}
    Environment variables:
        JENKINS_ADDR
        JENKINS_ADMIN_USER
        JENKINS_ADMIN_PASS
EOF
}

if [[ $# -gt 0 ]];then usage;exit 1; fi

if [[ "$JENKINS_ADMIN_PASS" == "stdin" ]]; then
  read -esp "[info] stdin option on, enter Jenkins admin password: " JENKINS_ADMIN_PASS
  printf "\n"
fi

export JENKINS_ADDR
export JENKINS_ADMIN_USER
export JENKINS_ADMIN_PASS

for i in ${JENKINS_SETUP_SCRIPTS}; do
  cmd_args=($JENKINS_SCRIPT_RUN_WRAPPER "./$i")
  echo "[info] running ${cmd_args[*]}"
  eval "${cmd_args[@]}"
done
