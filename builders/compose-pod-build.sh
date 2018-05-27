#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

LOCAL_DIR="$(cd "$(dirname $0)" && pwd)"

echo "[info] getting all information required for the build to start..."

VAULT_ADDR="$(curl -Ssf \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/vault_address?raw)"

BUILD_TAG="$(git rev-parse --short HEAD)"

PREV_BUILD_TAG="$(curl -Ss \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_tag?raw)"

REGISTRY_ADDRESS="$(curl -Ssf \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/docker_registry_address?raw)"

REGISTRY_PATH="$(curl -Ssf \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/docker_registry_path?raw)"

REGISTRY_CREDENTIALS="$(curl -Ssf -X GET \
  -H "X-Vault-Token:${VAULT_TOKEN}" \
  "${VAULT_ADDR}/v1/secret/operations/docker-registry" | jq -re .data.value)"

REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"

BUILD_DIR="$(curl -Ssf \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_dir?raw)"

# Config file creation order, if not found: bundled -> pod_name -> pod_profile -> auto
COMPOSE_FILE="${WORKSPACE}/${BUILD_DIR}/docker-compose.yml"
if [[ ! -f "${COMPOSE_FILE}" ]] && [[ ! -f "${COMPOSE_FILE}.j2" ]]; then
  if ! cp -v "${LOCAL_DIR}/docker-compose-${POD_NAME}.hcl.j2" "${COMPOSE_FILE}.j2"; then
    COMPOSE_PROFILE="$(curl -Ss \
      ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/compose_profile?raw || echo 'false')"
    if ! cp -v "${LOCAL_DIR}/docker-compose-${COMPOSE_PROFILE}.hcl.j2" "${COMPOSE_FILE}.j2"; then
      cp -v "${LOCAL_DIR}/docker-compose-auto.yml.j2" "${COMPOSE_FILE}.j2"
    fi
  fi
fi

NOMAD_FILE="${WORKSPACE}/${BUILD_DIR}/nomad-job.hcl"
if [[ ! -f "${NOMAD_FILE}" ]] && [[ ! -f "${NOMAD_FILE}.j2" ]]; then
  if ! cp -v "${LOCAL_DIR}/nomad-job-${POD_NAME}.hcl.j2" "${NOMAD_FILE}.j2"; then
    NOMAD_PROFILE="$(curl -Ss \
      ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/nomad_profile?raw || echo 'false')"
    if ! cp -v "${LOCAL_DIR}/nomad-job-${NOMAD_PROFILE}.hcl.j2" "${NOMAD_FILE}.j2"; then
      cp -v "${LOCAL_DIR}/nomad-job-auto.hcl.j2" "${NOMAD_FILE}.j2"
    fi
  fi
fi

export REGISTRY_ADDRESS
export REGISTRY_USERNAME
export REGISTRY_PASSWORD
export REGISTRY_PATH
export POD_NAME
export BUILD_TAG

echo "[info] parsing jinja2 templates, if any..."

# Parsing all jinja2 templates
while IFS='' read -r -d '' f; do
  ansible all -i localhost, \
    --connection=local \
    -m template \
    -a "src=${f} dest=${f%%.j2}"
done < <(find "${WORKSPACE}/${BUILD_DIR}" -type f -name '*.j2' -print0)

echo "[info] validating nomad job file..."

nomad validate \
  "${NOMAD_FILE}"

nomad run \
  -output "${NOMAD_FILE}" > "${WORKSPACE}/${BUILD_DIR}/nomad-job.json"

if [[ "${BUILD_TAG}" == "${PREV_BUILD_TAG}" ]]; then
  echo "[warning] commit id is the same, will not build again!"
  exit 0
fi

trap 'docker-compose -f "${COMPOSE_FILE}" --project-name "${POD_NAME}-${BUILD_TAG}" down -v --rmi all --remove-orphans' EXIT

docker login "${REGISTRY_ADDRESS}" \
  --username="${REGISTRY_USERNAME}" \
  --password-stdin <<< ${REGISTRY_PASSWORD} >/dev/null

echo "[info] building docker images..."

docker-compose \
  -f "${COMPOSE_FILE}" \
  --project-name "${POD_NAME}-${BUILD_TAG}" \
  --no-ansi \
  build --no-cache

echo "[info] pushing docker images..."

docker-compose \
  -f "${COMPOSE_FILE}" \
  --project-name "${POD_NAME}-${BUILD_TAG}" \
  --no-ansi \
  push

curl -Ssf -X PUT \
  -d "${BUILD_TAG}" \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_tag >/dev/null

