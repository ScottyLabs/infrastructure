# Keycloak group
resource "keycloak_group" "devops" {
  realm_id  = data.keycloak_realm.scottylabs.id
  parent_id = keycloak_group.projects.id
  name      = "devops"
}

# Full admin policy
resource "vault_policy" "devops" {
  name   = "devops"
  policy = <<-EOT
    # Manage all secrets
    path "secret/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Manage AppRole auth
    path "auth/approle/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # View OIDC auth
    path "auth/oidc/*" {
      capabilities = ["read", "list"]
    }

    # View policies
    path "sys/policies/*" {
      capabilities = ["read", "list"]
    }

    # View auth methods
    path "sys/auth" {
      capabilities = ["read"]
    }
  EOT
}

# Map Keycloak group to OpenBao policy
resource "vault_identity_group" "devops" {
  name     = "devops"
  type     = "external"
  policies = [vault_policy.devops.name]
}

resource "vault_identity_group_alias" "devops" {
  name           = "/projects/devops"
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.devops.id
}
