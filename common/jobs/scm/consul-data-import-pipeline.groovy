node {
  stage('checkout') {
    scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/bootstrap/scm_url?raw").trim()
    scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/bootstrap/scm_branch?raw").trim()
    checkout_info = checkout([$class: 'GitSCM', 
      branches: [[name: scm_branch]], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: scm_url]]])
  }
  stage('import') {
    sh '''#!/usr/bin/env bash
    set -xeEuo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    DOCKER_REGISTRY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/global/docker_registry_address?raw)"
    DOCKER_REGISTRY_PATH="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/global/docker_registry_path?raw)"
    while IFS='' read -r -d '' f; do
      ansible all -i localhost, --connection=local -m template -a "src=${f} dest=${f%%.j2}"
    done < <(find . -type f -name '*.j2' -print0)
    TAG_VERSION="$(
      curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/data/qa/images/sys-py-yaml-to-consul/current_build_tag?raw \
      || curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/data/integration/images/sys-py-yaml-to-consul/current_build_tag?raw \
      || curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/data/sandbox/images/sys-py-yaml-to-consul/current_build_tag?raw
    )"
    docker run --rm \
      -v "$(pwd)/config:/config" \
      -v "$(pwd)/import:/import" \
      --net=host \
      ${DOCKER_REGISTRY_ADDRESS}/$DOCKER_REGISTRY_PATH/sys-py-yaml-to-consul:${TAG_VERSION}
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}
