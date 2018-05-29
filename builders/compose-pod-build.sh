#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

echo "[info] getting all information required for the build to start..."

BUILDERS_DIR="$(cd "$(dirname $0)" && pwd)"

BUILD_TAG="$(git rev-parse --short HEAD)"

CURRENT_BUILD_TAG="${CURRENT_BUILD_TAG:-"0000000"}"

REGISTRY_CREDENTIALS="$(curl -Ssf -X GET \
  -H "X-Vault-Token:${VAULT_TOKEN}" \
  "${VAULT_ADDR}/v1/secret/operations/docker-registry" | jq -re .data.value)"

REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"

# Config file creation order, if not found: bundled -> pod_name -> pod_profile -> auto
COMPOSE_PROFILE="${COMPOSE_PROFILE:-"none"}"
COMPOSE_FILE="${WORKSPACE}/${CHECKOUT_DIR}/docker-compose.yml"
if [[ ! -f "${COMPOSE_FILE}" ]] && [[ ! -f "${COMPOSE_FILE}.j2" ]]; then
  cp -v "${BUILDERS_DIR}/docker-compose-${POD_NAME}.hcl.j2" "${COMPOSE_FILE}.j2" 2>/dev/null \
  || cp -v "${BUILDERS_DIR}/docker-compose-${COMPOSE_PROFILE}.hcl.j2" "${COMPOSE_FILE}.j2" 2>/dev/null \
  || cp -v "${BUILDERS_DIR}/docker-compose-auto.yml.j2" "${COMPOSE_FILE}.j2"
fi

BUILD_PROFILE="${BUILD_PROFILE:-"none"}"
DOCKER_FILE="${WORKSPACE}/${CHECKOUT_DIR}/Dockerfile"
if [[ ! -f "${DOCKER_FILE}" ]] && [[ ! -f "${DOCKER_FILE}.j2" ]]; then
  # Will fail if no Dockerfile present
  cp -v "${BUILDERS_DIR}/Dockerfile-${POD_NAME}.j2" "${DOCKER_FILE}.j2" 2>/dev/null \
  || cp -v "${BUILDERS_DIR}/Dockerfile-${BUILD_PROFILE}.j2" "${DOCKER_FILE}.j2" 2>/dev/null \
  || find "${WORKSPACE}/${CHECKOUT_DIR}" -type f -name 'Dockerfile' | grep -q '.'
fi

DEPLOY_PROFILE="${DEPLOY_PROFILE:-"none"}"
NOMAD_FILE="${WORKSPACE}/${CHECKOUT_DIR}/nomad-job.hcl"
if [[ ! -f "${NOMAD_FILE}" ]] && [[ ! -f "${NOMAD_FILE}.j2" ]]; then
  cp -v "${BUILDERS_DIR}/nomad-job-${POD_NAME}.hcl.j2" "${NOMAD_FILE}.j2" 2>/dev/null \
  || cp -v "${BUILDERS_DIR}/nomad-job-${DEPLOY_PROFILE}.hcl.j2" "${NOMAD_FILE}.j2" 2>/dev/null \
  || cp -v "${BUILDERS_DIR}/nomad-job-auto.hcl.j2" "${NOMAD_FILE}.j2"
fi

export REGISTRY_USERNAME
export REGISTRY_PASSWORD
export BUILD_TAG

echo "[info] parsing jinja2 templates, if any..."

# Parsing all jinja2 templates, except for .dot directores
while IFS='' read -r -d '' f; do
  ansible all -i localhost, \
    --connection=local \
    -m template \
    -a "src=${f} dest=${f%%.j2}"
done < <(find "${WORKSPACE}/${CHECKOUT_DIR}" -path "${WORKSPACE}/${CHECKOUT_DIR}/.*" -prune -o -name '*.j2' -print0)

echo "[info] validating nomad job file..."

nomad validate \
  "${NOMAD_FILE}"

nomad run \
  -output "${NOMAD_FILE}" > "${WORKSPACE}/${CHECKOUT_DIR}/nomad-job.json"

if [[ "${BUILD_TAG}" == "${CURRENT_BUILD_TAG}" ]]; then
  echo "[warning] commit id is the same, will not build again!"
  exit 0
fi

trap 'docker-compose -f "${COMPOSE_FILE}" --project-name "${POD_NAME}-${BUILD_TAG}" down -v --rmi all --remove-orphans' EXIT

docker login "${DOCKER_REGISTRY_ADDRESS}" \
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
  ${CONSUL_HTTP_ADDR}/v1/kv/platform/data/${PLATFORM_ENVIRONMENT}/${POD_CATEGORY}/${POD_NAME}/current_build_tag >/dev/null

