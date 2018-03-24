#!/usr/bin/env bash
set -eEo pipefail
trap '{ RC=$?; echo "[error] exit code $RC running $(eval echo $BASH_COMMAND)"; exit $RC; }'  ERR

vault_reset() {
  consul kv delete -recurse vault && sleep 0.5
  echo "[info] vault data purged"
  vault_init=$(curl --silent -X PUT -d "{\"secret_shares\":1,\"secret_threshold\":1}" ${VAULT_ADDR}/v1/sys/init)
  VAULT_ROOT_TOKEN=$(echo ${vault_init} | jq -re .root_token)
  VAULT_UNSEAL_KEY=$(echo ${vault_init} | jq -re .keys[0])
  curl --silent -X PUT -d "{\"key\": \"${VAULT_UNSEAL_KEY}\"}" ${VAULT_ADDR}/v1/sys/unseal && sleep 0.25
  echo "[info] vault unsealed"
  curl --silent -X POST -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d '{"type":"approle"}' ${VAULT_ADDR}/v1/sys/auth/approle
  echo "[info] vault enabled approle backend"
  curl --silent -X PUT -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d "{\"type\":\"syslog\"}" ${VAULT_ADDR}/v1/sys/audit/syslog
  echo "[info] vault enabled syslog audit backend"
  curl --silent -X PUT -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d '{"value":"HelloWorldSecret"}' ${VAULT_ADDR}/v1/secret/hello
  echo "[info] vault written hello secret"
  curl --silent -X PUT -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d '{"policy":"{\"path\":{\"secret/hello\":{\"capabilities\":[\"read\",\"list\"]}}"}' ${VAULT_ADDR}/v1/sys/policy/app-f85b911a
  curl --silent -X PUT -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d '{"policy":"{\"path\":{\"auth/approle/role/app-f85b911a/secret-id\":{\"capabilities\":[\"read\",\"create\",\"update\"]}}"}' ${VAULT_ADDR}/v1/sys/policy/app-admin
  curl --silent -X PUT -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d '{"policy":"{\"path\":{\"auth/approle/role/app-f85b911a/secret-id\":{\"capabilities\":[\"read\"]}}"}' ${VAULT_ADDR}/v1/sys/policy/app-read
  curl --silent -X PUT -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d '{"secret_id_ttl":"5m","token_ttl":"5m","token_max_ttl":"10m","policies":["app-f85b911a"]}' ${VAULT_ADDR}/v1/auth/approle/role/app-f85b911a
  echo "[info] vault policies written"
  APP_ADMIN_VAULT_TOKEN="$(curl --silent -X POST -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d '{"policies":["app-admin"]}' ${VAULT_ADDR}/v1/auth/token/create | jq -re .auth.client_token)"
  APP_F85B911A_VAULT_ROLE_ID="$(curl --silent -X GET -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" ${VAULT_ADDR}/v1/auth/approle/role/app-f85b911a/role-id | jq -re .data.role_id)"
  APP_READ_VAULT_TOKEN="$(curl --silent -X POST -H "X-Vault-Token:${VAULT_ROOT_TOKEN}" -d '{"policies":["app-read"]}' ${VAULT_ADDR}/v1/auth/token/create | jq -re .auth.client_token)"
  echo "[info] APP_ADMIN_VAULT_TOKEN: ${APP_ADMIN_VAULT_TOKEN}"
  echo "[info] APP_F85B911A_VAULT_ROLE_ID: ${APP_F85B911A_VAULT_ROLE_ID}"
  echo "[info] APP_READ_VAULT_TOKEN: ${APP_READ_VAULT_TOKEN}"
  token_renew_seconds=$(curl --silent -X POST -H "X-Vault-Token:${APP_ADMIN_VAULT_TOKEN}" -d '{"increment": "48h"}' "${VAULT_ADDR}/v1/auth/token/renew-self" | jq -re .auth.lease_duration)
  echo "[info] test self token renewal passed, seconds=${token_renew_seconds}"
  # generate secret-id for approle and wrap it (will transfer to app at deploy)
  approle_secid_unwrap_token="$(curl --silent -X POST -H "X-Vault-Token:${APP_ADMIN_VAULT_TOKEN}" -H "X-Vault-Wrap-TTL:60" ${VAULT_ADDR}/v1/auth/approle/role/app-f85b911a/secret-id | jq -re .wrap_info.token)"
  # unwrap secret-id (on the application side)
  approle_vault_secret_id="$(curl --silent -X POST -H "X-Vault-Token:${approle_secid_unwrap_token}" "${VAULT_ADDR}/v1/sys/wrapping/unwrap" | jq -re .data.secret_id)"
  # unwrapping a second time should fail
  ! curl --silent -X POST -H "X-Vault-Token:${approle_secid_unwrap_token}" "${VAULT_ADDR}/v1/sys/wrapping/unwrap" | jq -re .data.secret_id >/dev/null
  # get approle token (on the application side)
  approle_token="$(curl --silent -X POST -H "X-Vault-Token:${approle_vault_secret_id}" -d "{\"role_id\":\"${APP_F85B911A_VAULT_ROLE_ID}\",\"secret_id\":\"${approle_vault_secret_id}\"}" "${VAULT_ADDR}/v1/auth/approle/login" | jq -re .auth.client_token)"
  # use approle token to read secret (on the application side)
  secret="$(curl --silent -X GET -H "X-Vault-Token:$approle_token" "$VAULT_ADDR/v1/secret/hello" | jq -re .data.value)"
  echo "[info] vault token wrap/unwrap tests passed, secret=$secret"
}

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
vault_init=$(curl --connect-timeout 4 --silent ${VAULT_ADDR}/v1/sys/init | jq -r .initialized)
vault_sealed=$(curl --connect-timeout 4 --silent ${VAULT_ADDR}/v1/sys/seal-status | jq -r .sealed)

if [[ "${vault_init}" == "false" ]] || [[ "${vault_sealed}" == "true" ]]; then
  vault_reset
fi
