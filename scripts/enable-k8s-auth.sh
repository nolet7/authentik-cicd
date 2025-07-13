#!/bin/bash

set -euo pipefail

VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
VAULT_NAMESPACE=${VAULT_NAMESPACE:-""}
VAULT_TOKEN=${VAULT_TOKEN:-$(cat ~/vault-token.jwt)}

# Path in Vault to configure
VAULT_SECRET_PATH="secret/Dev-secret/authentik"

# Kubernetes Auth
AUTH_PATH="auth/kubernetes"
ROLE_NAME="authentik-role"
POLICY_NAME="authentik-policy"
SA_NAME="vault-auth"
SA_NAMESPACE="default"

echo "[INFO] Starting Vault Kubernetes auth configuration..."

# ---------------------------
# Fetch Kubernetes values
# ---------------------------
echo "[INFO] Fetching Kubernetes SA JWT, CA, and Host..."
KUBE_HOST=$(kubectl config view --raw -o jsonpath="{.clusters[0].cluster.server}")
SECRET_NAME=$(kubectl -n $SA_NAMESPACE get sa $SA_NAME -o jsonpath="{.secrets[0].name}")
SA_JWT=$(kubectl -n $SA_NAMESPACE get secret $SECRET_NAME -o jsonpath="{.data.token}" | base64 --decode)
CA_CRT=$(kubectl -n $SA_NAMESPACE get secret $SECRET_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode)

# ---------------------------
# Enable Kubernetes Auth
# ---------------------------
if ! vault auth list | grep -q "^$AUTH_PATH/"; then
  echo "[INFO] Enabling Kubernetes auth method at $AUTH_PATH..."
  vault auth enable kubernetes
else
  echo "[INFO] Kubernetes auth already enabled."
fi

# ---------------------------
# Configure Kubernetes Auth
# ---------------------------
echo "[INFO] Configuring Kubernetes Auth connection to cluster..."
vault write ${AUTH_PATH}/config \
  token_reviewer_jwt="$SA_JWT" \
  kubernetes_host="$KUBE_HOST" \
  kubernetes_ca_cert="$CA_CRT" \
  issuer="https://kubernetes.default.svc" \
  skip_tls_verify=true

# ---------------------------
# Write Policy
# ---------------------------
POLICY_FILE="./vault/policies/authentik-policy.hcl"
echo "[INFO] Writing Vault policy: $POLICY_NAME..."
vault policy write $POLICY_NAME $POLICY_FILE

# ---------------------------
# Create Role
# ---------------------------
echo "[INFO] Creating Vault role: $ROLE_NAME..."
vault write ${AUTH_PATH}/role/${ROLE_NAME} \
  bound_service_account_names=$SA_NAME \
  bound_service_account_namespaces=$SA_NAMESPACE \
  policies=$POLICY_NAME \
  ttl=24h

# ---------------------------
# Optional: Populate Vault secret values
# ---------------------------
echo "[INFO] Creating Vault secrets at path: $VAULT_SECRET_PATH (if not exists)..."
vault kv get $VAULT_SECRET_PATH >/dev/null 2>&1 || \
vault kv put $VAULT_SECRET_PATH \
  AUTHENTIK_SECRET_KEY="REPLACE_ME_SECRET_KEY" \
  PG_PASS="REPLACE_ME_DB_PASS" \
  SMTP_PASS="REPLACE_ME_SMTP_PASS"

echo "[SUCCESS] Vault Kubernetes integration setup complete."

