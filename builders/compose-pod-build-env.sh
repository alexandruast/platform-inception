#!/usr/bin/env bash

BUILDERS_DIR="$(cd "$(dirname $0)" && pwd)"

ansible-playbook -i 127.0.0.1, \
  --connection=local \
  --module-path=${BUILDERS_DIR} \
  ${BUILDERS_DIR}/build-env.yml
