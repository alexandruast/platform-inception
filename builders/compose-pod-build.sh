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

# getting the shell file to source with all variables inside prefix
echo "[info] getting all dynamic variables from consul..."
export CONSUL_PREFIX="${PLATFORM_ENVIRONMENT}/${POD_NAME}"
: > .jenkins-profile
for v in $(curl -Ssf \
  "${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}?recurse=true" \
  | jq --arg STRIP "${#CONSUL_PREFIX}" -r \
  '.[] | (.Key|ascii_upcase|.[$STRIP|tonumber+1:]) + ":" + .Value'); \
do
  b64encstr="$(echo ${v} | cut -d ":" -f2)"
  b64decstr="$(echo ${b64encstr} | openssl enc -base64 -d)"
  echo ${v} | sed -e "s|${b64encstr}|\"${b64decstr}\"|g" | tr ":" "="
  echo "export $(echo ${v} | sed -e "s|${b64encstr}|\"${b64decstr}\"|g" | tr ":" "=")" >> .jenkins-profile
done
source .jenkins-profile

# Config file creation order, if not found: bundled -> pod_name -> pod_profile -> auto
COMPOSE_PROFILE="${COMPOSE_PROFILE:-null}"
COMPOSE_FILE="${WORKSPACE}/${BUILD_DIR}/docker-compose.yml"
if [[ ! -f "${COMPOSE_FILE}" ]] && [[ ! -f "${COMPOSE_FILE}.j2" ]]; then
  if ! cp -v "${LOCAL_DIR}/docker-compose-${POD_NAME}.hcl.j2" "${COMPOSE_FILE}.j2" 2>/dev/null; then
    if ! cp -v "${LOCAL_DIR}/docker-compose-${COMPOSE_PROFILE}.hcl.j2" "${COMPOSE_FILE}.j2" 2>/dev/null; then
      cp -v "${LOCAL_DIR}/docker-compose-auto.yml.j2" "${COMPOSE_FILE}.j2"
    fi
  fi
fi

NOMAD_PROFILE="${NOMAD_PROFILE:-null}"
NOMAD_FILE="${WORKSPACE}/${BUILD_DIR}/nomad-job.hcl"
if [[ ! -f "${NOMAD_FILE}" ]] && [[ ! -f "${NOMAD_FILE}.j2" ]]; then
  if ! cp -v "${LOCAL_DIR}/nomad-job-${POD_NAME}.hcl.j2" "${NOMAD_FILE}.j2" 2>/dev/null; then
    if ! cp -v "${LOCAL_DIR}/nomad-job-${NOMAD_PROFILE}.hcl.j2" "${NOMAD_FILE}.j2" 2>/dev/null; then
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

# Parsing all jinja2 templates, except for .dot directores
while IFS='' read -r -d '' f; do
  ansible all -i localhost, \
    --connection=local \
    -m template \
    -a "src=${f} dest=${f%%.j2}"
done < <(find "${WORKSPACE}/${BUILD_DIR}" -path "${WORKSPACE}/${BUILD_DIR}/.*" -prune -o -name '*.j2' -print0)

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

