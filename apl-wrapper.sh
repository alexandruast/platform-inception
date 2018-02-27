#!/usr/bin/env bash
# This script provides a convenient wrapper over ansible-playbook command
# Warning: this script is NOT POSIX compliant, and was never meant to be!
set -eEo pipefail
trap 'echo "[error] exit code $? running $(eval echo $BASH_COMMAND)"' ERR

readonly ANSIBLE_TAGS_DEFAULT='all'
readonly ANSIBLE_SSH_PORT_DEFAULT=22
declare -a cmd_args

usage() {
  cat << EOF
    Usage: ${0##*/} [-i user@hostname,] [-t tags] playbook.yml
    Environment variables:
        ANSIBLE_TARGET
        ANSIBLE_SSH_PORT
EOF
}

if [[ $# -lt 1 ]];then usage;exit 1; fi
while getopts i:t: opt; do
  case $opt in
    i) ANSIBLE_TARGET=$OPTARG;;
    t) ANSIBLE_TAGS=$OPTARG;;
  esac
done && shift $((OPTIND -1))
if [[ $# -gt 1 ]];then usage;exit 1; fi
readonly ANSIBLE_PLAYBOOK=$1
readonly ANSIBLE_TAGS=${ANSIBLE_TAGS:-${ANSIBLE_TAGS_DEFAULT}}
readonly ANSIBLE_SSH_PORT=${ANSIBLE_SSH_PORT:-${ANSIBLE_SSH_PORT_DEFAULT}}
readonly ANSIBLE_TARGET=${ANSIBLE_TARGET}
readonly ANSIBLE_DIR=$(dirname $ANSIBLE_PLAYBOOK)

case "$ANSIBLE_TARGET" in
  127.0.0.1)
    ansible_args=('-i' "$ANSIBLE_TARGET," '--connection=local')
    ;;
  *)
    ansible_args=('-i' "$ANSIBLE_TARGET,")
    ;;
esac

cmd_args=(
  "ANSIBLE_HOST_KEY_CHECKING=False"
  ansible-playbook
  ${ansible_args[@]}
  "--module-path=$ANSIBLE_DIR/roles"
  "--extra-vars=\"ansible_ssh_port=$ANSIBLE_SSH_PORT\""
  "--extra-vars=@$ANSIBLE_DIR/vars/main.yml"
  $ANSIBLE_PLAYBOOK
  "--tags=$ANSIBLE_TAGS"
)

# Running ansible playbook
echo "[info] running ${cmd_args[*]}"
eval "${cmd_args[@]}"

