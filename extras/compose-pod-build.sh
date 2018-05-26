#!/usr/bin/env bash
set -xeEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

readonly VAULT_ADDR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/vault_address?raw)"

readonly CHECKOUT_COMMIT_ID="$(curl -Ssf http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_commit_id?raw)"
readonly POD_TAG="${CHECKOUT_COMMIT_ID:0:7}"

readonly PREVIOUS_BUILD_TAG="$(curl -Ss ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_tag?raw)"

if [[ "${POD_TAG}" == "${PREVIOUS_BUILD_TAG}" ]]; then
  echo [warning] commit id is the same, will not build again!
  exit 0
fi

readonly REGISTRY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/docker_registry_address?raw)"
readonly REGISTRY_PATH="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/docker_registry_path?raw)"

readonly REGISTRY_CREDENTIALS="$(curl -Ssf -X GET \
  -H "X-Vault-Token:${VAULT_TOKEN}" \
  "${VAULT_ADDR}/v1/secret/operations/docker-registry" | jq -re .data.value)"
readonly REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
readonly REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"

readonly BUILD_DIR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_dir?raw)"

readonly BASE_COMPOSE_TEMPLATE="${WORKSPACE}/${BUILD_DIR}/docker-compose-base.yml.j2"

cat << EOF > "${BASE_COMPOSE_FILE}"
version: '3'
  services:
    {{ POD_NAME }}:
      image: {{ REGISTRY_ADDRESS }}/{{ REGISTRY_PATH }}/{{ POD_NAME }}:{{ POD_TAG }}
      build: ./
EOF

readonly BASE_COMPOSE_FILE="${BASE_COMPOSE_TEMPLATE%%.j2}"

readonly EXPECTED_COMPOSE_FILE="${WORKSPACE}/${BUILD_DIR}/docker-compose.yml"

export REGISTRY_ADDRESS
export REGISTRY_USERNAME
export REGISTRY_PASSWORD
export REGISTRY_PATH
export POD_NAME
export POD_TAG

while IFS='' read -r -d '' f; do
  ansible all -i localhost, --connection=local -m template -a "src=${f} dest=${f%%.j2}"
done < <(find "${WORKSPACE}/${BUILD_DIR}" -type f -name '*.j2' -print0)

nomad validate "${WORKSPACE}/${BUILD_DIR}/nomad-job.hcl"
nomad run -output "${WORKSPACE}/${BUILD_DIR}/nomad-job.hcl" > "${WORKSPACE}/${BUILD_DIR}/nomad-job.json"

compose_file="${EXPECTED_COMPOSE_FILE}"

[[ -f "${EXPECTED_COMPOSE_FILE}" ]] || compose_file="${BASE_COMPOSE_FILE}"

trap 'docker-compose -f "${compose_file}" --project-name "${POD_NAME}-${POD_TAG}" down -v --rmi all --remove-orphans' EXIT

docker login "${REGISTRY_ADDRESS}" \
  --username="${REGISTRY_USERNAME}" \
  --password-stdin <<< ${REGISTRY_PASSWORD} >/dev/null

docker-compose -f "${compose_file}" --project-name "${POD_NAME}-${POD_TAG}" --no-ansi build --no-cache
docker-compose -f "${compose_file}" --project-name "${POD_NAME}-${POD_TAG}" --no-ansi push
curl -Ssf -X PUT -d "${POD_TAG}" ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_tag >/dev/null
