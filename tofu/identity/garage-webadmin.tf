resource "keycloak_openid_client" "garage_webadmin" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "garage-webadmin"
  name      = "Garage Web Admin"

  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://garage.scottylabs.org/auth/oauth2/keycloak/authorization-code-callback"
  ]
}

resource "keycloak_openid_group_membership_protocol_mapper" "garage_webadmin_groups" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = keycloak_openid_client.garage_webadmin.id
  name      = "groups"

  claim_name = "groups"
  full_path  = true
}

resource "random_password" "garage_webadmin_jwt" {
  length  = 64
  special = false
}

# Combined env file consumed by caddy via bao-agent's project-secret template.
# bao-agent renders /run/secrets/garage-webadmin.env with KEY=VALUE pairs by
# uppercasing each map key.
resource "vault_kv_secret_v2" "garage_webadmin_env" {
  mount = "secret"
  name  = "projects/garage-webadmin/prod/env"

  data_json = jsonencode({
    oidc_client_secret = keycloak_openid_client.garage_webadmin.client_secret
    jwt_shared_key     = random_password.garage_webadmin_jwt.result
  })
}

output "garage_webadmin_client_secret" {
  value     = keycloak_openid_client.garage_webadmin.client_secret
  sensitive = true
}
