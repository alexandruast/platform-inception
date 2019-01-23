#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

echo "[info] getting all information required for the build to start..."

BUILDERS_ABSOLUTE_DIR="$(cd "$(dirname $0)" && pwd)"

BUILD_TAG="$(git rev-parse --short HEAD)"

REGISTRY_CREDENTIALS="$(curl -Ssf -X GET \
  -H "X-Vault-Token:${VAULT_TOKEN}" \
  "${VAULT_ADDR}/v1/secret/operations/docker-registry" | jq -re .data.value)"

REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"

export REGISTRY_USERNAME
export REGISTRY_PASSWORD
export BUILD_TAG

if [ -n "${VAULT_SECRETS}" ]; then
  for secret_key in $(echo "${VAULT_SECRETS}" | jq -re .[] | tr '\n' ',' | sed -e 's/,$/\n/'); do
    secret_value="$(curl -Ssf -X GET \
      -H "X-Vault-Token:${VAULT_TOKEN}" \
      "${VAULT_ADDR}/v1/secret/operations/${secret_key}" | jq -re .data.value)"
    export ${!secret_key}="${secret_value}"
  done
fi

echo "[info] copying profile templates..."

ansible-playbook -i 127.0.0.1, \
  --connection=local \
  --module-path=${BUILDERS_ABSOLUTE_DIR} \
  ${BUILDERS_ABSOLUTE_DIR}/copy-profile-templates.yml

echo "[info] parsing jinja2 templates, if any..."

ansible-playbook -i 127.0.0.1, \
  --connection=local \
  --module-path=${BUILDERS_ABSOLUTE_DIR} \
  ${BUILDERS_ABSOLUTE_DIR}/parse-all-templates.yml

COMPOSE_FILE="${WORKSPACE}/${CHECKOUT_DIR}/docker-compose.yml"
NOMAD_FILE="${WORKSPACE}/${CHECKOUT_DIR}/nomad-job.hcl"

echo "[info] validating nomad job file..."

nomad validate \
  "${NOMAD_FILE}"

nomad run \
  -output "${NOMAD_FILE}" > "${WORKSPACE}/${CHECKOUT_DIR}/nomad-job.json"

if [[ "${BUILD_TAG}" == "${CURRENT_BUILD_TAG}" ]]; then
  echo "[warning] commit id is the same, will not build again!"
  exit 0
fi

trap 'docker-compose -f "${COMPOSE_FILE}" --project-name "${SERVICE_NAME}-${BUILD_TAG}" down -v --rmi all --remove-orphans' EXIT

docker login "${DOCKER_REGISTRY_ADDRESS}" \
  --username="${REGISTRY_USERNAME}" \
  --password-stdin <<< ${REGISTRY_PASSWORD} >/dev/null

echo "[info] building docker images..."

docker-compose \
  -f "${COMPOSE_FILE}" \
  --project-name "${SERVICE_NAME}-${BUILD_TAG}" \
  --no-ansi \
  build --no-cache

echo "[info] pushing docker images..."

docker-compose \
  -f "${COMPOSE_FILE}" \
  --project-name "${SERVICE_NAME}-${BUILD_TAG}" \
  --no-ansi \
  push

curl -Ssf -X PUT \
  -d "${BUILD_TAG}" \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform/data/${PLATFORM_ENVIRONMENT}/${SERVICE_CATEGORY}/${SERVICE_NAME}/current_build_tag >/dev/null

