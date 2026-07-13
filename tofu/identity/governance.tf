locals {
  # Per-project secrets written by the tfgen outputs
  governance_project_secrets = [
    "SENTRY_DSN",
    "POSTHOG_KEY",
    "POSTHOG_HOST",
    "OIDC_CLIENT_ID",
    "OIDC_CLIENT_SECRET",
    "KEYCLOAK_URL",
    "KEYCLOAK_REALM",
    "OAUTH_RELAY_URL",
    "PROJECT_GROUP",
    "PROJECT_ADMIN_GROUP",
    "KEYCLOAK_ADMIN_CLIENT_ID",
    "KEYCLOAK_ADMIN_CLIENT_SECRET",
    "LITELLM_API_KEY",
    "LITELLM_BASE_URL",
    "CDN_S3_ENDPOINT",
    "CDN_S3_BUCKET",
    "CDN_ACCESS_KEY_ID",
    "CDN_SECRET_ACCESS_KEY",
    "CDN_PUBLIC_URL",
  ]
}

# Policy for governance CI to manage project identity resources
resource "vault_policy" "governance" {
  name   = "governance"
  policy = <<-EOT
    # Manage vault policies (project dev/prod policies)
    path "sys/policies/acl/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Manage identity groups and aliases
    path "identity/group" {
      capabilities = ["create", "update"]
    }

    path "identity/group/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "identity/group-alias" {
      capabilities = ["create", "update"]
    }

    path "identity/group-alias/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Read auth backend config (for mount accessor lookup)
    path "sys/auth" {
      capabilities = ["read"]
    }

    path "sys/mounts/auth/*" {
      capabilities = ["read"]
    }

    # Allow vault provider to create child tokens
    path "auth/token/create" {
      capabilities = ["create", "update"]
    }

    %{~for secret in local.governance_project_secrets~}
    path "secret/data/secretspec/+/+/${secret}" {
      capabilities = ["create", "read", "update", "delete"]
    }

    path "secret/metadata/secretspec/+/+/${secret}" {
      capabilities = ["create", "read", "update", "delete"]
    }
    %{~endfor~}

    # LiteLLM master key for governance to call the management API
    path "secret/data/infra/litellm-master-key" {
      capabilities = ["read"]
    }

    # Read shared CI cache credentials (cachix, sccache)
    path "secret/data/shared/*" {
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

# Service-account client governance authenticates as to manage OIDC clients
resource "keycloak_openid_client" "governance_cli" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "governance-cli"
  name      = "Governance CLI"

  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  service_accounts_enabled     = true
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  frontchannel_logout_enabled  = true

  valid_redirect_uris = ["/*"]
  web_origins         = ["/*"]
}

# Realm-management roles for managing OIDC clients and users
resource "keycloak_openid_client_service_account_role" "governance_cli_realm_management" {
  for_each = toset(["query-clients", "manage-clients", "view-users", "manage-users"])

  realm_id                = data.keycloak_realm.scottylabs.id
  service_account_user_id = keycloak_openid_client.governance_cli.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = each.value
}
