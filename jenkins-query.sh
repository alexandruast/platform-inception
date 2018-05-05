#!/usr/bin/env bash
# this script requires mo - https://github.com/tests-always-included/mo
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR
which mo >/dev/null 2>&1
readonly max_timeout=120
readonly connect_timeout=5
declare -a auth_args EXCEPTIONS PASS

usage() {
  cat << EOF
    Usage: ${0##*/} script.groovy
    Environment variables:
      JENKINS_ADDR
      JENKINS_ADMIN_USER
      JENKINS_ADMIN_PASS
EOF
}

if [[ $# -ne 1 ]];then usage;exit 1; fi
readonly JENKINS_SCRIPT=$1

if [[ "$JENKINS_ADMIN_PASS" == "stdin" ]]; then
  read -esp "[info] stdin option on, enter Jenkins admin password: " JENKINS_ADMIN_PASS
  printf "\n"
fi

for var in JENKINS_ADDR JENKINS_ADMIN_USER JENKINS_ADMIN_PASS; do
  if [[ ${!var} == '' ]]; then echo "[error] ${var} variable is empty!"; exit 1; fi
done

auth_args=('--user' $JENKINS_ADMIN_USER:$JENKINS_ADMIN_PASS)

# Check connection to jenkins with retry logic
readonly wait_between=2
readonly wait_until=$(( $(date +%s) + $max_timeout + $wait_between))
runtime=$(date +%s)
while (( $runtime < $wait_until )); do
  curl --connect-timeout $connect_timeout --silent --output /dev/null $JENKINS_ADDR || true
  web_status=$(curl --connect-timeout $connect_timeout ${auth_args[*]} --silent --output /dev/null --write-out "%{http_code}" ${JENKINS_ADDR}/api/json?pretty=true || true)
  case $web_status in
    200) break ;;
    *) sleep $wait_between & wait ;;
  esac
  runtime=$(date +%s)
done

if [[ $web_status != 200 ]]; then
  echo "[error] got the following http response from jenkins: ${web_status}"
  exit 1
fi

# Get CSRF status from jenkins
CSRF="$(curl --connect-timeout $connect_timeout ${auth_args[*]} -s ${JENKINS_ADDR}/api/json?pretty=true | jq -r '.useCrumbs' | awk '{print tolower($0)}')"

if [[ $CSRF == "true" ]]; then
  token=$(curl --connect-timeout $connect_timeout ${auth_args[*]} -s ${JENKINS_ADDR}/crumbIssuer/api/json | jq -r '.crumbRequestField + "=" + .crumb')
  auth_args=(${auth_args[@]} -d $token)
fi

# Fill variable placeholders in groovy file with mo
script=$(cat $JENKINS_SCRIPT | mo)
# Running groovy script
result=$(curl --connect-timeout $connect_timeout --silent ${auth_args[*]} --data-urlencode "script=$script" ${JENKINS_ADDR}/scriptText)

# Output parse and cleanup
EXCEPTIONS=('Exception:')
PASS=('Result: org.kohsuke.stapler.HttpRedirect' 'Result: false' 'Result: true' '200' '201')

for i in "${EXCEPTIONS[@]}"; do
  if [[ ${result} == *$i* ]]; then
    echo "[error] got exception from jenkins:"
    echo "$result" | sed "s/^/[error] /g"
    exit 1
  fi
done

for i in "${PASS[@]}"; do
  if [[ ${result} == *$i* ]]; then
    result=''; break
  fi
done

if [[ $result != '' ]]; then
  echo "$result" | sed "s/^/[info] /g"
fi
