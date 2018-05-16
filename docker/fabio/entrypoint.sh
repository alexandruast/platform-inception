#!/usr/bin/env bash
set -euEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

DOCKER_HOST_IP="$(/sbin/route -n | awk '/UG[ \t]/{print $2}')"
export FABIO_registry_consul_addr="http://${DOCKER_HOST_IP}:8500"

exec gosu fabio "$@"

