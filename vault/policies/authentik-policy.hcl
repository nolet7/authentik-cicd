# Allows reading Authentik secrets for the app
path "secret/data/Dev-secret/authentik" {
  capabilities = ["read"]
}

# Required if your deployment uses metadata (not common for static secrets)
path "secret/metadata/Dev-secret/authentik" {
  capabilities = ["read"]
}

