#!/usr/bin/env bash
# This script provides a convenient wrapper over ansible-playbook command
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

readonly ANSIBLE_TAGS_DEFAULT='all'
readonly ANSIBLE_PORT_DEFAULT=22
declare -a cmd_args

usage() {
  cat << EOF
    Usage: ${0##*/} [-i user@hostname,] [-j jump@jumphost] [-e extra-vars] [-t tags] playbook.yml
    Environment variables:
        ANSIBLE_TARGET
        ANSIBLE_JUMPHOST
        ANSIBLE_PORT
        ANSIBLE_EXTRAVARS
EOF
}

if [[ $# -lt 1 ]];then usage;exit 1; fi
while getopts i:j:t:e:c: opt; do
  case $opt in
    i) ANSIBLE_TARGET=${OPTARG};;
    j) ANSIBLE_JUMPHOST=${OPTARG};;
    t) ANSIBLE_TAGS=${OPTARG};;
    e) ANSIBLE_EXTRAVARS=${OPTARG};;
  esac
done && shift $((OPTIND -1))
if [[ $# -gt 1 ]];then usage;exit 1; fi
readonly ANSIBLE_PLAYBOOK=$1
readonly ANSIBLE_TAGS=${ANSIBLE_TAGS:-${ANSIBLE_TAGS_DEFAULT}}
readonly ANSIBLE_PORT=${ANSIBLE_PORT:-${ANSIBLE_PORT_DEFAULT}}
readonly ANSIBLE_EXTRAVARS=${ANSIBLE_EXTRAVARS:-"{}"}
readonly ANSIBLE_CHECK_MODE=${ANSIBLE_CHECK_MODE:-false}
readonly ANSIBLE_TARGET=${ANSIBLE_TARGET}
readonly ANSIBLE_JUMPHOST=${ANSIBLE_JUMPHOST:-none}
readonly ANSIBLE_DIR=$(dirname $ANSIBLE_PLAYBOOK)

case "${ANSIBLE_TARGET}" in
  127.0.0.1)
    connect_args=('-i' "${ANSIBLE_TARGET}," '--connection=local')
    ;;
  *)
    connect_args=('-i' "${ANSIBLE_TARGET},")
    ;;
esac

case "${ANSIBLE_JUMPHOST}" in
  none)
    connect_args=(${connect_args[@]} "--ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ForwardAgent=yes'")
    ;;
  *)
    connect_args=(${connect_args[@]} "--ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ForwardAgent=yes -o ProxyCommand=\"ssh -W %h:%p -q ${ANSIBLE_JUMPHOST}\"'")
    ;;
esac

cmd_args=(
  "ANSIBLE_HOST_KEY_CHECKING=False"
  ansible-playbook
  ${connect_args[@]}
  "--module-path=${ANSIBLE_DIR}/roles"
  "--extra-vars=\"ansible_port=${ANSIBLE_PORT}\""
  "--extra-vars=@${ANSIBLE_DIR}/vars/main.yml"
  "--extra-vars=\"${ANSIBLE_EXTRAVARS}\""
  $ANSIBLE_PLAYBOOK
  "--tags=${ANSIBLE_TAGS}"
)

# Running ansible playbook
echo "[info] running ${cmd_args[*]}"
eval "${cmd_args[@]}"

