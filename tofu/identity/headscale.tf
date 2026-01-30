resource "keycloak_openid_client" "headscale" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "headscale"
  name      = "Headscale"

  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://headscale.scottylabs.org/oidc/callback"
  ]
}

resource "keycloak_openid_client" "headplane" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "headplane"
  name      = "Headplane"

  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://headplane.scottylabs.org/admin/oidc/callback"
  ]
}

resource "keycloak_openid_group_membership_protocol_mapper" "headscale_groups" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = keycloak_openid_client.headscale.id
  name      = "groups"

  claim_name = "groups"
  full_path  = true
}

resource "keycloak_openid_group_membership_protocol_mapper" "headplane_groups" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = keycloak_openid_client.headplane.id
  name      = "groups"

  claim_name = "groups"
  full_path  = true
}

output "headscale_client_secret" {
  value     = keycloak_openid_client.headscale.client_secret
  sensitive = true
}

output "headplane_client_secret" {
  value     = keycloak_openid_client.headplane.client_secret
  sensitive = true
}

# Store secrets in OpenBao for bao-agent to fetch
resource "vault_kv_secret_v2" "headscale_oidc" {
  mount = "secret"
  name  = "infra/headscale-oidc"

  data_json = jsonencode({
    CLIENT_SECRET = keycloak_openid_client.headscale.client_secret
  })
}

resource "vault_kv_secret_v2" "headplane_oidc" {
  mount = "secret"
  name  = "infra/headplane-oidc"

  data_json = jsonencode({
    CLIENT_SECRET = keycloak_openid_client.headplane.client_secret
  })
}

resource "random_bytes" "headplane_agent" {
  length = 32
}

resource "random_password" "headplane_cookie" {
  length  = 32
}

resource "vault_kv_secret_v2" "headplane_cookie" {
  mount = "secret"
  name  = "infra/headplane-cookie"

  data_json = jsonencode({
    SECRET = random_password.headplane_cookie.result
  })
}

resource "vault_kv_secret_v2" "headplane_agent" {
  mount = "secret"
  name  = "infra/headplane-agent"

  data_json = jsonencode({
    SECRET = random_bytes.headplane_agent.base64
  })
}
