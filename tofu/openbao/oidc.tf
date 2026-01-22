resource "vault_jwt_auth_backend" "oidc" {
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "https://idp.scottylabs.org/realms/scottylabs"
  oidc_client_id     = "openbao"
  oidc_client_secret = var.oidc_client_secret
  default_role       = "default"
}

resource "vault_jwt_auth_backend_role" "default" {
  backend   = vault_jwt_auth_backend.oidc.path
  role_name = "default"
  role_type = "oidc"

  bound_audiences = ["openbao"]
  user_claim      = "preferred_username"
  token_policies  = ["default"]

  allowed_redirect_uris = [
    "https://secrets2.scottylabs.org/v1/auth/oidc/callback",
    "https://secrets2.scottylabs.org/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]
}
