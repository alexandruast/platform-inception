#!/usr/bin/env bash
# Temporarily using a docker hub account with clear password, please do not abuse :)
set -euEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

# Get required data from Consul/Vault using tokens
CONSUL_ADDR="${CONSUL_ADDR:-http://127.0.0.1:8500}"
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
NOMAD_ADDR="${NOMAD_ADDR:-http://127.0.0.1:4646}"

DOCKER_REGISTRY_ADDRESS="docker.io"
DOCKER_REGISTRY_CREDENTIALS="platformdemo:63hu8y1L7X3BBel8"

DOCKER_REGISTRY_USERNAME="${DOCKER_REGISTRY_CREDENTIALS%:*}"
DOCKER_REGISTRY_PASSWORD="${DOCKER_REGISTRY_CREDENTIALS#*:}"

DOCKER_REPOSITORY_NAME="${DOCKER_REGISTRY_USERNAME}"
DOCKER_SERVICE_NAME="system"
DOCKER_SERVICE_VERSION="fabio-20180517091106"

# Assemble name, push job to nomad
DOCKER_BUILD_IMAGE="${DOCKER_REGISTRY_ADDRESS}/${DOCKER_REPOSITORY_NAME}/${DOCKER_SERVICE_NAME}:${DOCKER_SERVICE_VERSION}"
