node {
  stage('checkout') {
    gitBranch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_branch?raw").trim()
    gitURL = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/scm_url?raw").trim()
    checkout_info = checkout([$class: 'GitSCM',
      branches: [[name: gitBranch]],
      doGenerateSubmoduleConfigurations: false,
      submoduleCfg: [],
      userRemoteConfigs: [[url: gitURL]]])
    sh("curl -Ssf -X PUT -d ${checkout_info.GIT_COMMIT} http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_commit_id >/dev/null")
  }
  stage('build') {
    withCredentials([
        string(credentialsId: 'JENKINS_VAULT_TOKEN', variable: 'VAULT_TOKEN'),
        string(credentialsId: 'JENKINS_VAULT_ROLE_ID', variable: 'VAULT_ROLE_ID'),
    ]) {
      sh '''#!/usr/bin/env bash
      set -xeEuo pipefail
      trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
      CHECKOUT_COMMIT_ID="$(curl -Ssf http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_commit_id?raw)"
      PREVIOUS_BUILD_TAG="$(curl -Ss ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_tag?raw)"
      POD_TAG="${CHECKOUT_COMMIT_ID:0:7}"
      VAULT_ADDR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/vault_address?raw)"
      REGISTRY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/docker_registry_address?raw)"
      REGISTRY_PATH="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/docker_registry_path?raw)"
      REGISTRY_CREDENTIALS="$(curl -Ssf -X GET \
        -H "X-Vault-Token:${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/operations/docker-registry" | jq -re .data.value)"
      REGISTRY_USERNAME="${REGISTRY_CREDENTIALS%:*}"
      REGISTRY_PASSWORD="${REGISTRY_CREDENTIALS#*:}"
      export REGISTRY_ADDRESS
      export REGISTRY_USERNAME
      export REGISTRY_PASSWORD
      export REGISTRY_PATH
      export POD_NAME
      export POD_TAG
      docker login "${REGISTRY_ADDRESS}" --username="${REGISTRY_USERNAME}" --password-stdin <<< ${REGISTRY_PASSWORD} >/dev/null
      BUILD_DIR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_dir?raw)"
      while IFS='' read -r -d '' f; do
        ansible all -i localhost, --connection=local -m template -a "src=${f} dest=${f%%.j2}"
      done < <(find "${WORKSPACE}/${BUILD_DIR}" -type f -name '*.j2' -print0)
      nomad validate "${WORKSPACE}/${BUILD_DIR}/nomad-job.hcl"
      nomad run -output "${WORKSPACE}/${BUILD_DIR}/nomad-job.hcl" > "${WORKSPACE}/${BUILD_DIR}/nomad-job.json"
      compose_file="${WORKSPACE}/${BUILD_DIR}/docker-compose.yml"
      if [[ ! -f "${compose_file}" ]]; then
        compose_file="${WORKSPACE}/${BUILD_DIR}/docker-compose-auto.yml"
        COMPOSE_YAML="version: '3'\nservices:\n  ${POD_NAME}:\n    image: ${REGISTRY_ADDRESS}/${REGISTRY_PATH}/${POD_NAME}:${POD_TAG}\n    build: ./"
        echo -e "${COMPOSE_YAML}" > "${compose_file}"
      fi
      if [[ "${POD_TAG}" == "${PREVIOUS_BUILD_TAG}" ]]; then
        echo [warning] commit id is the same, will not build again!
        exit 0
      fi
      trap 'docker-compose -f "${compose_file}" --project-name "${POD_NAME}-${POD_TAG}" down -v --rmi all --remove-orphans' EXIT
      docker-compose -f "${compose_file}" --project-name "${POD_NAME}-${POD_TAG}" --no-ansi build --no-cache
      docker-compose -f "${compose_file}" --project-name "${POD_NAME}-${POD_TAG}" --no-ansi push
      curl -Ssf -X PUT -d "${POD_TAG}" ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_tag >/dev/null
      '''
    }
  }
  stage('deploy') {
    sh '''#!/usr/bin/env bash
    set -xeEuo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    SSH_DEPLOY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/ssh_deploy_address?raw)"
    trap 'ssh -S "${WORKSPACE}/ssh-control-socket" -O exit ${SSH_DEPLOY_ADDRESS}' EXIT
    SSH_OPTS='-o LogLevel=error -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ExitOnForwardFailure=yes'
    CHECKOUT_COMMIT_ID="$(curl -Ssf http://127.0.0.1:8500/v1/kv/${PLATFORM_ENVIRONMENT}/${POD_NAME}/checkout_commit_id?raw)"
    POD_TAG="${CHECKOUT_COMMIT_ID:0:7}"
    tunnel_port=$(perl -e 'print int(rand(999)) + 58000')
    ssh ${SSH_OPTS} -f -N -M -S "${WORKSPACE}/ssh-control-socket" -L ${tunnel_port}:127.0.0.1:4646 ${SSH_DEPLOY_ADDRESS}
    BUILD_DIR="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-config/${PLATFORM_ENVIRONMENT}/${POD_NAME}/build_dir?raw)"
    cd "${WORKSPACE}/${BUILD_DIR}"
    NOMAD_ADDR=http://127.0.0.1:${tunnel_port}
    JOB_PLAN_DATA="$(curl -Ssf -X POST -d @nomad-job.json ${NOMAD_ADDR}/v1/job/${POD_NAME}/plan)"
    FAILED_ALLOCS="$(echo "${JOB_PLAN_DATA}" | grep 'FailedTGAllocs' | jq -rc .FailedTGAllocs)"
    [[ "${FAILED_ALLOCS}" == "null" ]]
    JOB_POST_DATA="$(curl -Ssf -X POST -d @nomad-job.json ${NOMAD_ADDR}/v1/jobs)"
    JOB_EVAL_ID="$(echo "${JOB_POST_DATA}" | jq -re .EvalID)"
    DEPLOYMENT_ID="$(curl -Ssf ${NOMAD_ADDR}/v1/evaluation/${JOB_EVAL_ID} | jq -re .DeploymentID)"
    while :; do
      sleep 10 &
      wait || true
      deployment_status="$(curl -Ssf ${NOMAD_ADDR}/v1/deployment/${DEPLOYMENT_ID} | jq -re .Status)"
      case "${deployment_status}" in
        successful)
          curl -Ssf -X PUT -d "${POD_TAG}" ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/${PLATFORM_ENVIRONMENT}/${POD_NAME}/deploy_tag >/dev/null
          exit 0
        ;;
        failed)
          exit 1
      esac
    done
    exit 1
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}