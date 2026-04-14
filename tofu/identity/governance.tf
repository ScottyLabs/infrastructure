# Policy for governance CI to manage project identity resources
resource "vault_policy" "governance" {
  name = "governance"
  policy = <<-EOT
    # Manage vault policies (project dev/prod policies)
    path "sys/policies/acl/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Manage identity groups and aliases
    path "identity/group/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Read OIDC auth backend config (for mount accessor)
    path "sys/auth" {
      capabilities = ["read"]
    }
  EOT
}

# AppRole for governance CI
resource "vault_approle_auth_backend_role" "governance" {
  backend        = vault_auth_backend.approle.path
  role_name      = "governance"
  token_policies = [vault_policy.governance.name]

  token_ttl     = 3600
  token_max_ttl = 86400
  secret_id_ttl = 0
}

output "governance_approle_role_id" {
  value = vault_approle_auth_backend_role.governance.role_id
}
