#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

BUILDERS_DIR="$(cd "$(dirname $0)" && pwd)"

ansible-playbook -i 127.0.0.1, \
  --connection=local \
  --module-path=${BUILDERS_DIR} \
  ${BUILDERS_DIR}/build-env.yml
