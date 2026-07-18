# Enables machine authentication for NixOS hosts
resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

locals {
  hosts = toset([
    "infra-01",
    "deploy-01",
    "snoopy",
    "bus-sign-display",
  ])
}

# AppRole for each host, on the shared infra secrets policy
resource "vault_approle_auth_backend_role" "host" {
  for_each       = local.hosts
  backend        = vault_auth_backend.approle.path
  role_name      = each.value
  token_policies = [vault_policy.infra.name]

  token_ttl     = 3600   # 1 hour
  token_max_ttl = 86400  # 24 hours
  secret_id_ttl = 0      # no expiration
}

output "approle_role_ids" {
  value = { for k, v in vault_approle_auth_backend_role.host : k => v.role_id }
}
