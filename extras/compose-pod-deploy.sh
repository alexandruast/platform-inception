#!/usr/bin/env bash
set -xeEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

SSH_OPTS=(
  "-o LogLevel=error"
  "-o StrictHostKeyChecking=no"
  "-o UserKnownHostsFile=/dev/null"
  "-o BatchMode=yes"
  "-o ExitOnForwardFailure=yes"
)

SSH_DEPLOY_ADDRESS="$(curl -Ssf \
  ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/ssh_deploy_address?raw)"

trap 'ssh -S "${WORKSPACE}/ssh-control-socket" -O exit ${SSH_DEPLOY_ADDRESS}' EXIT

# Creating an SSH tunnel to the nomad server
TUNNEL_PORT=$(perl -e 'print int(rand(999)) + 58000')

ssh ${SSH_OPTS[*]} \
  -f -N -M \
  -S "${WORKSPACE}/ssh-control-socket" \
  -L ${TUNNEL_PORT}:127.0.0.1:4646 \
  ${SSH_DEPLOY_ADDRESS}

NOMAD_ADDR=http://127.0.0.1:${TUNNEL_PORT}

# Is there a previous deployment for this pod?
if curl -Ssf ${NOMAD_ADDR}/v1/job/${POD_NAME} >/dev/null; then
  # Try job planning, so we can catch any issues before actually deploying stuff
  JOB_PLAN_DATA="$(curl -Ssf -X POST \
    -d @nomad-job.json \
    ${NOMAD_ADDR}/v1/job/${POD_NAME}/plan)"
  # To go further with the deploy, the FailedTGAllocs field must be null
  FAILED_ALLOCS="$(echo "${JOB_PLAN_DATA}" \
    | grep 'FailedTGAllocs' \
    | jq -rc .FailedTGAllocs)"
  [[ "${FAILED_ALLOCS}" == "null" ]]
fi

# Posting job data
JOB_POST_DATA="$(curl -Ssf -X POST -d @nomad-job.json ${NOMAD_ADDR}/v1/jobs)"

# Getting information
JOB_EVAL_ID="$(echo "${JOB_POST_DATA}" \
  | jq -re .EvalID)"

DEPLOYMENT_ID="$(curl -Ssf \
  ${NOMAD_ADDR}/v1/evaluation/${JOB_EVAL_ID} \
  | jq -re .DeploymentID)"

# Infinite loop until status is failed or successful
while :; do
  sleep 10 &
  wait || true
  DEPLOYMENT_STATUS="$(curl -Ssf ${NOMAD_ADDR}/v1/deployment/${DEPLOYMENT_ID} | jq -re .Status)"
  case "${DEPLOYMENT_STATUS}" in
    successful)
      curl -Ssf -X PUT -d "${POD_TAG}" ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/deploy_tag >/dev/null
      exit 0
    ;;
    failed)
      exit 1
  esac
done
exit 1
