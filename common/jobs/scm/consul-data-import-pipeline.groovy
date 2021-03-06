node {
  stage('checkout') {
    conf_scm_url = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/global/conf_scm_url?raw").trim()
    conf_scm_branch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/global/conf_scm_branch?raw").trim()
    checkout_info = checkout([$class: 'GitSCM',
      branches: [[name: conf_scm_branch]],
      doGenerateSubmoduleConfigurations: false,
      extensions:[
        [$class: 'CleanBeforeCheckout']
      ],
      submoduleCfg: [],
      userRemoteConfigs: [[url: conf_scm_url]]])
  }
  stage('import') {
    sh '''#!/usr/bin/env bash
    set -xeEuo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    DOCKER_REGISTRY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/${PLATFORM_ENVIRONMENT}/global/docker_registry_address?raw)"
    DOCKER_REGISTRY_PATH="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/conf/${PLATFORM_ENVIRONMENT}/global/docker_registry_path?raw)"
    while IFS='' read -r -d '' f; do
      ansible all -i localhost, --connection=local -m template -a "src=${f} dest=${f%%.j2}"
    done < <(find . -type f -name '*.j2' -print0)
    TAG_VERSION="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform/data/${PLATFORM_ENVIRONMENT}/images/sys-py-yaml-to-consul/current_build_tag?raw)"
    docker run --rm \
      -v "$(pwd)/config:/config" \
      -v "$(pwd)/import:/import" \
      --net=host \
      ${DOCKER_REGISTRY_ADDRESS}/$DOCKER_REGISTRY_PATH/sys-py-yaml-to-consul:${TAG_VERSION}
    '''
  }
}
