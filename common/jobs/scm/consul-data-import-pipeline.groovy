node {
  stage('checkout') {
    scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/bootstrap/scm_branch?raw").trim()
    scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/bootstrap/scm_url?raw").trim()
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
    REGISTRY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/docker_registry_address?raw)"
    REGISTRY_PATH="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/docker_registry_path?raw)"
    while IFS='' read -r -d '' f; do
      ansible all -i localhost, --connection=local -m template -a "src=${f} dest=${f%%.j2}"
    done < <(find . -type f -name '*.j2' -print0)
    TAG_VERSION="$(
      curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/qa/yaml-to-consul/build_tag?raw \
      || curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/integration/yaml-to-consul/build_tag?raw \
      || curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/sandbox/yaml-to-consul/build_tag?raw
    )"
    docker run --rm \
      -v "$(pwd)/config:/config" \
      -v "$(pwd)/import:/import" \
      --net=host \
      ${REGISTRY_ADDRESS}/$REGISTRY_PATH/yaml-to-consul:${TAG_VERSION}
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}
