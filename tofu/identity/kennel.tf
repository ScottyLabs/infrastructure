resource "vault_policy" "kennel" {
  name = "kennel"
  policy = <<-EOT
    path "secret/data/secretspec/+/+/*" {
      capabilities = ["read"]
    }

    path "secret/metadata/secretspec/+/+/*" {
      capabilities = ["list", "read"]
    }

    # Kennel writes the per-project Keycloak OIDC client_id and client_secret
    # here after reconciling each client; secretspec then resolves them like
    # any other declared secret.
    path "secret/data/secretspec/+/+/OIDC_CLIENT_ID" {
      capabilities = ["create", "update"]
    }

    path "secret/data/secretspec/+/+/OIDC_CLIENT_SECRET" {
      capabilities = ["create", "update"]
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

# Service-account client used by kennel to manage per-project OIDC clients
# (create, update redirect URIs, add/remove PR-preview URIs).
resource "keycloak_openid_client" "kennel" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "kennel"
  name      = "Kennel"

  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  service_accounts_enabled     = true
  standard_flow_enabled        = false
  direct_access_grants_enabled = false
}

data "keycloak_openid_client" "realm_management" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "realm-management"
}

data "keycloak_role" "manage_clients" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "manage-clients"
}

resource "keycloak_openid_client_service_account_role" "kennel_manage_clients" {
  realm_id                = data.keycloak_realm.scottylabs.id
  service_account_user_id = keycloak_openid_client.kennel.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = data.keycloak_role.manage_clients.name
}

resource "vault_kv_secret_v2" "kennel_keycloak_admin" {
  mount = "secret"
  name  = "infra/kennel-keycloak-admin"

  data_json = jsonencode({
    CLIENT_SECRET = keycloak_openid_client.kennel.client_secret
  })
}
