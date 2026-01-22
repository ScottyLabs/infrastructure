locals {
  projects = toset(jsondecode(file("${path.module}/projects.json")))
}

# Keycloak groups
resource "keycloak_group" "project" {
  for_each  = local.projects
  realm_id  = data.keycloak_realm.scottylabs.id
  parent_id = keycloak_group.projects.id
  name      = each.key
}

resource "keycloak_group" "project_admins" {
  for_each  = local.projects
  realm_id  = data.keycloak_realm.scottylabs.id
  parent_id = keycloak_group.project[each.key].id
  name      = "admins"
}

# OpenBao policies
resource "vault_policy" "project_dev" {
  for_each = local.projects
  name     = "${each.key}-dev"
  policy   = <<-EOT
    path "secret/data/projects/${each.key}/dev/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "secret/metadata/projects/${each.key}/dev/*" {
      capabilities = ["list", "read"]
    }
  EOT
}

resource "vault_policy" "project_prod" {
  for_each = local.projects
  name     = "${each.key}-prod"
  policy   = <<-EOT
    path "secret/data/projects/${each.key}/prod/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "secret/metadata/projects/${each.key}/prod/*" {
      capabilities = ["list", "read"]
    }
  EOT
}

# OpenBao groups
resource "vault_identity_group" "project_members" {
  for_each = local.projects
  name     = "${each.key}-members"
  type     = "external"
  policies = [vault_policy.project_dev[each.key].name]
}

resource "vault_identity_group_alias" "project_members" {
  for_each       = local.projects
  name           = "/projects/${each.key}"
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.project_members[each.key].id
}

resource "vault_identity_group" "project_admins" {
  for_each = local.projects
  name     = "${each.key}-admins"
  type     = "external"
  policies = [vault_policy.project_prod[each.key].name]
}

resource "vault_identity_group_alias" "project_admins" {
  for_each       = local.projects
  name           = "/projects/${each.key}/admins"
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.project_admins[each.key].id
}
