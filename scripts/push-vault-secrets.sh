#!/bin/bash

set -e

VAULT_ADDR="http://127.0.0.1:8200"
VAULT_TOKEN="${VAULT_TOKEN:-$(cat ~/vault-token.jwt 2>/dev/null || true)}"
SECRETS_FILE="vault/secrets.hcl"
SECRET_PATH="secret/Dev-secret/authentik"

if [ -z "$VAULT_TOKEN" ]; then
  echo "[ERROR] VAULT_TOKEN not set and not found in ~/vault-token.jwt"
  exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
  echo "[ERROR] Secrets file '$SECRETS_FILE' not found."
  exit 1
fi

# Convert key=value lines to -format="key=value"
PUT_ARGS=""
while IFS='=' read -r key value; do
  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs | sed 's/^"//;s/"$//')
  [ -z "$key" ] && continue
  PUT_ARGS+=" $key=\"$value\""
done < "$SECRETS_FILE"

echo "[INFO] Pushing secrets to Vault at path: $SECRET_PATH"
vault login "$VAULT_TOKEN" > /dev/null
eval vault kv put "$SECRET_PATH" $PUT_ARGS

echo "[INFO]  Secrets pushed successfully to Vault."

