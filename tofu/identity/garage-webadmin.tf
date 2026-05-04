resource "keycloak_openid_client" "garage_webadmin" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "garage-webadmin"
  name      = "Garage Web Admin"

  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://garage.scottylabs.org/auth/oauth2/scottylabs/authorization-code-callback"
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

resource "vault_kv_secret_v2" "garage_webadmin_oidc" {
  mount = "secret"
  name  = "infra/garage-webadmin-oidc"

  data_json = jsonencode({
    CLIENT_SECRET = keycloak_openid_client.garage_webadmin.client_secret
  })
}

resource "vault_kv_secret_v2" "garage_webadmin_jwt" {
  mount = "secret"
  name  = "infra/garage-webadmin-jwt"

  data_json = jsonencode({
    SECRET = random_password.garage_webadmin_jwt.result
  })
}

output "garage_webadmin_client_secret" {
  value     = keycloak_openid_client.garage_webadmin.client_secret
  sensitive = true
}
