#!/usr/bin/env bash

BUILDERS_ABSOLUTE_DIR="$(cd "$(dirname $0)" && pwd)"

echo "[info] populating env file from consul..."

ansible-playbook -i 127.0.0.1, \
  --connection=local \
  --module-path=${BUILDERS_ABSOLUTE_DIR} \
  ${BUILDERS_ABSOLUTE_DIR}/create-build-env.yml
