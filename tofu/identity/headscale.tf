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
