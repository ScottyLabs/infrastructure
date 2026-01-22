variable "oidc_client_secret" {
  description = "OIDC client secret from Keycloak"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_user" {
  type      = string
  sensitive = true
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true
}
