#!/usr/bin/env bash

BUILDERS_ABSOLUTE_DIR="$(cd "$(dirname $0)" && pwd)"

echo "[info] populating env file from consul..."

ansible-playbook -i 127.0.0.1, \
  --connection=local \
  --module-path=${BUILDERS_ABSOLUTE_DIR} \
  ${BUILDERS_ABSOLUTE_DIR}/create-build-env.yml

source "${WORKSPACE}/.build-env"

echo "[info] populating secrets from vault..."
shred "${WORKSPACE}/.build-secrets"
for secret_key in $(echo "${VAULT_SECRETS:-}" | jq -re .[] | tr '\n' ' ' | sed -e 's/ $/ /'); do
  secret_value="$(curl -Ssf -X GET \
    -H "X-Vault-Token:${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/secret/operations/${secret_key}" | jq -re .data.value)"
  echo "export ${secret_key^^}=\"${secret_value}\"" >> "${WORKSPACE}/.build-secrets"
done
