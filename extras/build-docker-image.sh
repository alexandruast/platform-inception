#!/usr/bin/env bash
# Temporarily using a docker hub account with clear password, please do not abuse :)
set -euEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

# Get required data from Consul/Vault using tokens
CONSUL_ADDR="${CONSUL_ADDR:-http://127.0.0.1:8500}"
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"

DOCKER_REGISTRY_ADDRESS="docker.io"
DOCKER_REGISTRY_CREDENTIALS="platformdemo:63hu8y1L7X3BBel8"

DOCKER_REGISTRY_USERNAME="${DOCKER_REGISTRY_CREDENTIALS%:*}"
DOCKER_REGISTRY_PASSWORD="${DOCKER_REGISTRY_CREDENTIALS#*:}"

DOCKER_REPOSITORY_NAME="${DOCKER_REGISTRY_USERNAME}"
DOCKER_SERVICE_NAME="system"
DOCKER_SERVICE_VERSION="fabio-$(date "+%Y%m%d%H%M%S")"

# Assemble name, login, build and push image
DOCKER_SERVICE_IMAGE="${DOCKER_REGISTRY_ADDRESS}/${DOCKER_REPOSITORY_NAME}/${DOCKER_SERVICE_NAME}:${DOCKER_SERVICE_VERSION}"

echo "[info] ${DOCKER_REGISTRY_ADDRESS} docker registry login..."
docker login "${DOCKER_REGISTRY_ADDRESS}" \
  --username="${DOCKER_REGISTRY_USERNAME}" \
  --password-stdin <<< ${DOCKER_REGISTRY_PASSWORD} >/dev/null

docker build -t ${DOCKER_SERVICE_IMAGE} ./
docker push ${DOCKER_SERVICE_IMAGE}