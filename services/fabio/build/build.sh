#!/usr/bin/env bash
set -euEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

# Get required data from Consul/Vault using tokens
# Temporarily using a docker hub account with clear password, please do not abuse :)
DOCKER_REGISTRY_URI="docker.io"
DOCKER_REGISTRY_CREDENTIALS="platformdemo:63hu8y1L7X3BBel8"

DOCKER_REGISTRY_USERNAME="${DOCKER_REGISTRY_CREDENTIALS%:*}"
DOCKER_REGISTRY_PASSWORD="${DOCKER_REGISTRY_CREDENTIALS#*:}"

echo "[info] ${DOCKER_REGISTRY_URI} docker registry login..."
docker login "${DOCKER_REGISTRY_URI}" \
  --username="${DOCKER_REGISTRY_USERNAME}" \
  --password-stdin <<< ${DOCKER_REGISTRY_PASSWORD} >/dev/null
