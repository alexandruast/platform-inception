node {
  stage('checkout') {
    gitBranch = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/bootstrap/scm_branch?raw").trim()
    gitURL = sh(returnStdout: true, script: "curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/bootstrap/scm_url?raw").trim()
    checkout_info = checkout([$class: 'GitSCM', 
      branches: [[name: gitBranch]], 
      doGenerateSubmoduleConfigurations: false, 
      submoduleCfg: [], 
      userRemoteConfigs: [[url: gitURL]]])
  }
  stage('import') {
    sh '''#!/usr/bin/env bash
    set -xeuEo pipefail
    trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
    REGISTRY_ADDRESS="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/docker_registry_address?raw)"
    REGISTRY_PATH="$(curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-settings/docker_registry_path?raw)"
    ansible all -i localhost, --connection=local -m template -a "src=config/main.yml.j2 dest=config/main.yml" >/dev/null
    TAG_VERSION="$(
      curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/qa/yaml-to-consul/tag_version?raw || \
      curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/integration/yaml-to-consul/tag_version?raw || \
      curl -Ssf ${CONSUL_HTTP_ADDR}/v1/kv/platform-data/sandbox/yaml-to-consul/tag_version?raw
    )"
    docker run --rm \
      -v "$(pwd)/config:/config" \
      -v "$(pwd)/import:/import" \
      ${REGISTRY_ADDRESS}/$REGISTRY_PATH/yaml-to-consul:${TAG_VERSION}
    '''
  }
  stage('cleanup') {
    cleanWs()
  }
}
