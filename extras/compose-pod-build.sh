#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

echo "[info] getting all information required for the build to start..."

AUTO_COMPOSE_TEMPLATE="$(cat << EOF
version: '3'
services:
  {{lookup('env','POD_NAME')}}:
    image: {{lookup('env','REGISTRY_ADDRESS')}}/{{lookup('env','REGISTRY_PATH')}}/{{lookup('env','POD_NAME')}}:{{lookup('env','BUILD_TAG')}}
    build: ./
EOF
)"

AUTO_NOMAD_TEMPLATE="$(cat << EOF
job "{{lookup('env','POD_NAME')}}" {
  datacenters = ["dc1"]
  type = "service"
  update {
    max_parallel = 1
  }
  group "{{lookup('env','POD_NAME')}}" {
    task "{{lookup('env','POD_NAME')}}-{{lookup('env','BUILD_TAG')}}" {
      driver = "docker"
      config {
        image = "{{lookup('env','REGISTRY_ADDRESS')}}/{{lookup('env','REGISTRY_PATH')}}/{{lookup('env','POD_NAME')}}:{{lookup('env','BUILD_TAG')}}"
        auth {
          server_address = "{{lookup('env','REGISTRY_ADDRESS')}}"
          username = "{{lookup('env','REGISTRY_USERNAME')}}"
          password = "{{lookup('env','REGISTRY_PASSWORD')}}"
        }
      }
      service {
        name = "{{lookup('env','POD_NAME')}}"
      }
    }
  }
}
EOF
)"

VAULT_ADDR="$(curl -Ssf \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/vault_address?raw)"

BUILD_TAG="$(git rev-parse --short HEAD)"

PREV_BUILD_TAG="$(curl -Ss \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_tag?raw)"

if [[ "${BUILD_TAG}" == "${PREV_BUILD_TAG}" ]]; then
  echo "[warning] commit id is the same, will not build again!"
  exit 0
fi

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
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_dir?raw)"

COMPOSE_FILE="${WORKSPACE}/${BUILD_DIR}/docker-compose.yml"
if [[ ! -f "${COMPOSE_FILE}" ]] && [[ ! -f "${COMPOSE_FILE}.j2" ]]; then
  COMPOSE_FILE="${WORKSPACE}/${BUILD_DIR}/docker-compose-auto.yml"
  echo "${AUTO_COMPOSE_TEMPLATE}" > "${COMPOSE_FILE}.j2"
fi

NOMAD_FILE="${WORKSPACE}/${BUILD_DIR}/nomad-job.hcl"
if [[ ! -f "${NOMAD_FILE}" ]] && [[ ! -f "${NOMAD_FILE}.j2" ]]; then
  NOMAD_FILE="${WORKSPACE}/${BUILD_DIR}/nomad-job-auto.hcl"
  echo "${AUTO_NOMAD_TEMPLATE}" > "${NOMAD_FILE}.j2"
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

