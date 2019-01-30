#!/usr/bin/env bash
set -eEuo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

echo "[info] getting all information required for the deploy to start..."

SSH_OPTS=(
  "-o LogLevel=error"
  "-o StrictHostKeyChecking=no"
  "-o UserKnownHostsFile=/dev/null"
  "-o BatchMode=yes"
  "-o ExitOnForwardFailure=yes"
)

trap 'ssh -S "${WORKSPACE}/ssh-control-socket" -O exit ${SSH_DEPLOY_ADDRESS}' EXIT

# Creating an SSH tunnel to the nomad server
TUNNEL_PORT=$(perl -e 'print int(rand(999)) + 58000')

echo "[info] SSH tunnel to ${SSH_DEPLOY_ADDRESS}:${TUNNEL_PORT} starting..."

ssh ${SSH_OPTS[*]} \
  -f -N -M \
  -S "${WORKSPACE}/ssh-control-socket" \
  -L ${TUNNEL_PORT}:127.0.0.1:4646 \
  ${SSH_DEPLOY_ADDRESS}

NOMAD_FILE="${WORKSPACE}/${CHECKOUT_DIR}/nomad-job.json"
NOMAD_ADDR=http://127.0.0.1:${TUNNEL_PORT}

echo "[info] getting information about currently running deployment for this service..."

# Is there a previous deployment for this service?
if curl -Ssf ${NOMAD_ADDR}/v1/job/${SERVICE_NAME} >/dev/null; then
  # Try job planning, so we can catch any issues before actually deploying stuff
  JOB_PLAN_DATA="$(curl -Ssf -X POST \
    -d "@${NOMAD_FILE}" \
    ${NOMAD_ADDR}/v1/job/${SERVICE_NAME}/plan)"
  # To go further with the deploy, the FailedTGAllocs field must be null
  FAILED_ALLOCS="$(echo "${JOB_PLAN_DATA}" \
    | grep 'FailedTGAllocs' \
    | jq -rc .FailedTGAllocs)"
  [[ "${FAILED_ALLOCS}" == "null" ]]
fi

echo "[info] posting job data to Nomad API..."

# Posting job data
JOB_POST_DATA="$(curl -Ssf -X POST \
  -d "@${WORKSPACE}/${CHECKOUT_DIR}/nomad-job.json" \
  ${NOMAD_ADDR}/v1/jobs)"

echo "[info] getting information back from Nomad API..."

# Getting information
JOB_EVAL_ID="$(echo "${JOB_POST_DATA}" | jq -re .EvalID)"

until [[ "${DEPLOYMENT_ID:-}" != "" ]] && [[ "${JOB_TYPE:-}" != "system" ]]; do
  sleep 1
  echo "[info] trying ${NOMAD_ADDR}/v1/evaluation/${JOB_EVAL_ID}"
  JOB_EVAL_DATA="$(curl -Ssf \
    ${NOMAD_ADDR}/v1/evaluation/${JOB_EVAL_ID})"
  # JOB_MODIFY_INDEX="$(echo "${JOB_EVAL_DATA}" | jq -re .JobModifyIndex)"
  # JOB_TYPE="$(echo "${JOB_EVAL_DATA}" | jq -re .Type)"
  DEPLOYMENT_ID="$(echo "${JOB_EVAL_DATA}" | jq -re .DeploymentID)"
done

echo "[info] waiting for deployment to finish..."

# Infinite loop until status is failed or successful
while :; do
  sleep 10 &
  wait || true

  # nomad system job currently does not support deployments
  # if [[ "${JOB_TYPE}" == "system" ]]; then
  #   JOB_DATA="$(curl -Ssf \
  #     ${NOMAD_ADDR}/v1/jobs?prefix=${SERVICE_NAME} | jq -re ".[] | select(.ModifyIndex==${JOB_MODIFY_INDEX})")"
  #   JOB_STATUS="$(echo "${JOB_DATA}"| jq -re .Status)"
  #   echo "[info] job status: ${JOB_STATUS:-unknown}"
  #   case "${JOB_STATUS}" in
  #     running)
  #       curl -Ssf -X PUT \
  #         -d "${CURRENT_BUILD_TAG}" \
  #         ${CONSUL_HTTP_ADDR}/v1/kv/platform/data/${PLATFORM_ENVIRONMENT}/${SERVICE_CATEGORY}/${SERVICE_NAME}/current_deploy_tag >/dev/null
  #       exit 0
  #     ;;
  #     dead)
  #       exit 1
  #   esac
  # else
  # fi

  DEPLOYMENT_STATUS="$(curl -Ssf \
    ${NOMAD_ADDR}/v1/deployment/${DEPLOYMENT_ID} \
    | jq -re .Status)"
  echo "[info] deployment status: ${DEPLOYMENT_STATUS}"

  case "${DEPLOYMENT_STATUS}" in
    successful)
      curl -Ssf -X PUT \
        -d "${CURRENT_BUILD_TAG}" \
        ${CONSUL_HTTP_ADDR}/v1/kv/platform/data/${PLATFORM_ENVIRONMENT}/${SERVICE_CATEGORY}/${SERVICE_NAME}/current_deploy_tag >/dev/null
      exit 0
    ;;
    failed|cancelled)
      exit 1
  esac
done  

# Script should never end here!
exit 1
