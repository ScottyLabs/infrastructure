# Keycloak OIDC client for Tailscale
resource "keycloak_openid_client" "tailscale" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "tailscale"
  name      = "Tailscale"

  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://login.tailscale.com/a/oauth_response"
  ]
}

# Output the client secret for Tailscale configuration
output "tailscale_client_secret" {
  value     = keycloak_openid_client.tailscale.client_secret
  sensitive = true
}
