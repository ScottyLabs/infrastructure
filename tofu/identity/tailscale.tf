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

  authentication_flow_binding_overrides {
    browser_id = keycloak_authentication_flow.tailscale_browser.id
  }
}

# Custom browser flow for Tailscale that shows both password form and IdP option
resource "keycloak_authentication_flow" "tailscale_browser" {
  realm_id    = data.keycloak_realm.scottylabs.id
  alias       = "tailscale-browser"
  description = "Browser flow for Tailscale with username/password and IdP options"
}

# Cookie authentication
resource "keycloak_authentication_execution" "tailscale_cookie" {
  realm_id          = data.keycloak_realm.scottylabs.id
  parent_flow_alias = keycloak_authentication_flow.tailscale_browser.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
}

# Forms subflow
resource "keycloak_authentication_subflow" "tailscale_forms" {
  realm_id          = data.keycloak_realm.scottylabs.id
  parent_flow_alias = keycloak_authentication_flow.tailscale_browser.alias
  alias             = "tailscale-forms"
  provider_id       = "basic-flow"
  requirement       = "ALTERNATIVE"

  depends_on = [keycloak_authentication_execution.tailscale_cookie]
}

# Username/password form inside the forms subflow
resource "keycloak_authentication_execution" "tailscale_username_password" {
  realm_id          = data.keycloak_realm.scottylabs.id
  parent_flow_alias = keycloak_authentication_subflow.tailscale_forms.alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
}

# Identity Provider Redirector (CMU SAML)
resource "keycloak_authentication_execution" "tailscale_idp" {
  realm_id          = data.keycloak_realm.scottylabs.id
  parent_flow_alias = keycloak_authentication_flow.tailscale_browser.alias
  authenticator     = "identity-provider-redirector"
  requirement       = "ALTERNATIVE"

  depends_on = [keycloak_authentication_subflow.tailscale_forms]
}

# Local Keycloak user for initial Tailscale setup
resource "keycloak_user" "tailscale_admin" {
  realm_id = data.keycloak_realm.scottylabs.id
  username = "tailscale-admin"
  enabled  = true

  email          = "admin+tailscale@scottylabs.org"
  email_verified = true
  first_name     = "Tailscale"
  last_name      = "Admin"

  initial_password {
    value     = var.tailscale_admin_password
    temporary = false
  }
}

# Output the client secret for Tailscale configuration
output "tailscale_client_secret" {
  value     = keycloak_openid_client.tailscale.client_secret
  sensitive = true
}
