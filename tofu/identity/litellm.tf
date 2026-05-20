resource "keycloak_openid_client" "litellm" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "litellm"
  name      = "LiteLLM"

  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://litellm.scottylabs.org/sso/callback"
  ]
}

resource "keycloak_openid_group_membership_protocol_mapper" "litellm_groups" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = keycloak_openid_client.litellm.id
  name      = "groups"

  claim_name = "groups"
  full_path  = true
}

resource "random_password" "litellm_master_key" {
  length  = 48
  special = false
}

resource "random_password" "litellm_salt_key" {
  length  = 48
  special = false
}

resource "vault_kv_secret_v2" "litellm_oidc" {
  mount = "secret"
  name  = "infra/litellm-oidc"

  data_json = jsonencode({
    CLIENT_SECRET = keycloak_openid_client.litellm.client_secret
  })
}

resource "vault_kv_secret_v2" "litellm_master_key" {
  mount = "secret"
  name  = "infra/litellm-master-key"

  data_json = jsonencode({
    MASTER_KEY = "sk-${random_password.litellm_master_key.result}"
  })
}

resource "vault_kv_secret_v2" "litellm_salt_key" {
  mount = "secret"
  name  = "infra/litellm-salt-key"

  data_json = jsonencode({
    SALT_KEY = random_password.litellm_salt_key.result
  })
}

resource "random_password" "cli_proxy_api_key" {
  length  = 48
  special = false
}

resource "vault_kv_secret_v2" "cli_proxy_api_key" {
  mount = "secret"
  name  = "infra/cli-proxy-api-key"

  data_json = jsonencode({
    API_KEY = random_password.cli_proxy_api_key.result
  })
}
