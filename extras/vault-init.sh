#!/usr/bin/env bash
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

vault_reset() {
  curl -Ssf -X DELETE ${CONSUL_HTTP_ADDR}/v1/kv/vault?recurse >/dev/null
  # sleep is required here, delete is not instant
  sleep 1
  echo "[info] vault data purged from consul"
  
  vault_init="$(curl -Ssf -X PUT \
    -d "{\"secret_shares\":1,\"secret_threshold\":1}" \
    ${VAULT_ADDR}/v1/sys/init)"
  sleep 1
  echo "[info] vault initialized"
  
  VAULT_ROOT_TOKEN="$(echo ${vault_init} | jq -re .root_token)"
  VAULT_UNSEAL_KEY="$(echo ${vault_init} | jq -re .keys[0])"
  
  # unseal all servers
  for s in ${VAULT_CLUSTER_IPS}; do
    curl -Ssf -X PUT \
      -d "{\"key\":\"${VAULT_UNSEAL_KEY}\"}" \
      http://${s}:8200/v1/sys/unseal >/dev/null
  done
  # sleep is required here, unseal is not instant
  sleep 0.25
  echo "[info] vault servers unsealed"
  
  # enable approle backend
  curl -Ssf -X POST \
    -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" \
    -d "{\"type\":\"approle\"}" \
    ${VAULT_ADDR}/v1/sys/auth/approle
  echo "[info] vault enabled approle backend"
  
  # enable syslog backend
  curl -Ssf -X PUT \
    -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" \
    -d "{\"type\":\"syslog\"}" \
    ${VAULT_ADDR}/v1/sys/audit/syslog
  echo "[info] vault enabled syslog audit backend"
  
  curl --silent -X PUT -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d '{"value":"HelloWorldSecret"}' ${VAULT_ADDR}/v1/secret/hello
  echo "[info] vault written hello secret"
  
  # importing app-f85b911a policy
  policy_name='app-f85b911a'
  policy_string=$(cat vault/policies/${policy_name}.json | jq -c . | sed 's/"/\\\"/g')
  curl -X PUT \
    -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" \
    -d "{\"policy\":\"${policy_string}\"}" ${VAULT_ADDR}/v1/sys/policy/${policy_name}
  
  # importing app-admin policy
  policy_name='app-admin'
  policy_string=$(cat vault/policies/${policy_name}.json | jq -c . | sed 's/"/\\\"/g')
  curl -X PUT \
    -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" \
    -d "{\"policy\":\"${policy_string}\"}" ${VAULT_ADDR}/v1/sys/policy/${policy_name}
    
  # importing app-read policy
  policy_name='app-read'
  policy_string=$(cat vault/policies/${policy_name}.json | jq -c . | sed 's/"/\\\"/g')
  curl -X PUT \
    -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" \
    -d "{\"policy\":\"${policy_string}\"}" ${VAULT_ADDR}/v1/sys/policy/${policy_name}

  curl --silent -X PUT \
    -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" \
    -d "{\"secret_id_ttl\":\"5m\",\"token_ttl\":\"5m\",\"token_max_ttl\":\"10m\",\"policies\":[\"app-f85b911a\"]}" \
    ${VAULT_ADDR}/v1/auth/approle/role/app-f85b911a
  echo "[info] vault policies written"
  
  APP_ADMIN_VAULT_TOKEN="$(curl --silent -X POST \
    -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" \
    -d "{\"policies\":[\"app-admin\"]}" \
    ${VAULT_ADDR}/v1/auth/token/create | jq -re .auth.client_token)"
  
  APP_F85B911A_VAULT_ROLE_ID="$(curl --silent -X GET \
    -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" \
    ${VAULT_ADDR}/v1/auth/approle/role/app-f85b911a/role-id | jq -re .data.role_id)"
  
  APP_READ_VAULT_TOKEN="$(curl --silent -X POST \
    -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" \
    -d "{\"policies\":[\"app-read\"]}" \
    ${VAULT_ADDR}/v1/auth/token/create | jq -re .auth.client_token)"
  
  echo "[info] APP_ADMIN_VAULT_TOKEN: ${APP_ADMIN_VAULT_TOKEN}"
  echo "[info] APP_F85B911A_VAULT_ROLE_ID: ${APP_F85B911A_VAULT_ROLE_ID}"
  echo "[info] APP_READ_VAULT_TOKEN: ${APP_READ_VAULT_TOKEN}"
  
  token_renew_seconds=$(curl --silent -X POST \
    -H "X-Vault-Token:${APP_ADMIN_VAULT_TOKEN}" \
    -d "{\"increment\": \"96h\"}" \
    "${VAULT_ADDR}/v1/auth/token/renew-self" | jq -re .auth.lease_duration)
  echo "[info] test self token renewal passed, seconds=${token_renew_seconds}"
  
  # generate secret-id for approle and wrap it (will transfer to app at deploy)
  approle_secid_unwrap_token="$(curl --silent -X POST \
    -H "X-Vault-Token:${APP_ADMIN_VAULT_TOKEN}" \
    -H "X-Vault-Wrap-TTL:60" \
    ${VAULT_ADDR}/v1/auth/approle/role/app-f85b911a/secret-id | jq -re .wrap_info.token)"
  
  # unwrap secret-id (on the application side)
  approle_vault_secret_id="$(curl --silent -X POST \
    -H "X-Vault-Token:${approle_secid_unwrap_token}" \
    ${VAULT_ADDR}/v1/sys/wrapping/unwrap | jq -re .data.secret_id)"
  
  # unwrapping a second time should fail
  ! curl --silent -X POST \
    -H "X-Vault-Token:${approle_secid_unwrap_token}" \
    ${VAULT_ADDR}/v1/sys/wrapping/unwrap | jq -re .data.secret_id >/dev/null
  
  # get approle token (on the application side)
  approle_token="$(curl --silent -X POST \
    -H "X-Vault-Token:${approle_vault_secret_id}" \
    -d "{\"role_id\":\"${APP_F85B911A_VAULT_ROLE_ID}\",\"secret_id\":\"${approle_vault_secret_id}\"}" \
    ${VAULT_ADDR}/v1/auth/approle/login | jq -re .auth.client_token)"
  
  # use approle token to read secret (on the application side)
  secret="$(curl --silent -X GET \
    -H "X-Vault-Token:$approle_token" \
    "$VAULT_ADDR/v1/secret/hello" | jq -re .data.value)"
  echo "[info] vault token wrap/unwrap tests passed, secret=$secret"
  
  JENKINS_CREDENTIAL_ID="APP_READ_VAULT_TOKEN" \
    JENKINS_CREDENTIAL_DESCRIPTION="Vault Token" \
    JENKINS_CREDENTIAL_SECRET="${APP_READ_VAULT_TOKEN}" \
    ./jenkins-query.sh common/credential-update.groovy
  JENKINS_CREDENTIAL_ID="APP_F85B911A_VAULT_ROLE_ID" \
    JENKINS_CREDENTIAL_DESCRIPTION="Vault Role ID" \
    JENKINS_CREDENTIAL_SECRET="${APP_F85B911A_VAULT_ROLE_ID}" \
    ./jenkins-query.sh common/credential-update.groovy
}

# uncomment this block to manually run this script
VAULT_CLUSTER_IPS="$(echo '["192.168.169.181","192.168.169.182"]' | jq -re .[])"
export VAULT_CLUSTER_IPS
export JENKINS_ADMIN_USER=admin
export JENKINS_ADMIN_PASS=welcome1
export JENKINS_ADDR=http://192.168.169.172:8080

VAULT_ADDR="http://$(echo "${VAULT_CLUSTER_IPS}" | head -1):8200"
CONSUL_HTTP_ADDR="http://$(echo "${VAULT_CLUSTER_IPS}" | head -1):8500"

# uncomment this block to always reset vault
vault_reset

# Don't use jq -re or curl -f here, because if the result is false it will error out
vault_init="$(curl -Ss --connect-timeout 4 ${VAULT_ADDR}/v1/sys/init | jq -r .initialized)"
vault_sealed="$(curl -Ss --connect-timeout 4 ${VAULT_ADDR}/v1/sys/seal-status | jq -r .sealed)"

if [[ "${vault_init}" == "false" ]] || [[ "${vault_sealed}" == "true" ]]; then
  vault_reset
fi
