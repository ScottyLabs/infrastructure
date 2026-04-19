resource "vault_policy" "kennel" {
  name = "kennel"
  policy = <<-EOT
    path "secret/data/secretspec/+/+/*" {
      capabilities = ["read"]
    }

    path "secret/metadata/secretspec/+/+/*" {
      capabilities = ["list", "read"]
    }
  EOT
}

resource "vault_approle_auth_backend_role" "kennel" {
  backend        = vault_auth_backend.approle.path
  role_name      = "kennel"
  token_policies = [vault_policy.kennel.name]

  token_ttl     = 3600
  token_max_ttl = 86400
  secret_id_ttl = 0
}

output "kennel_approle_role_id" {
  value = vault_approle_auth_backend_role.kennel.role_id
}
