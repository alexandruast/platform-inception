for scope in origin factory prod; do
  export JENKINS_NULL='null'
  for v in $(env | grep '^JENKINS_' | cut -f1 -d'='); do unset $v; done
  source ${scope}/.scope
  export JENKINS_ADMIN_PASS=$ci_admin_pass
  ip_var="${scope}_ip"
  export JENKINS_ADDR=http://${!ip_var}:${JENKINS_PORT}
  ./jenkins-query.sh common/is-online.groovy
  echo "${scope}-jenkins is online: ${JENKINS_ADDR} ${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASS}"
done