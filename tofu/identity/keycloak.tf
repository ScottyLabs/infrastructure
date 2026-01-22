data "keycloak_realm" "scottylabs" {
  realm = "scottylabs"
}

data "keycloak_openid_client" "openbao" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "openbao"
}

# Groups mapper to send full paths in token
resource "keycloak_openid_group_membership_protocol_mapper" "openbao_groups" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = data.keycloak_openid_client.openbao.id
  name      = "groups"

  claim_name = "groups"
  full_path  = true
}

# Parent group for all projects
resource "keycloak_group" "projects" {
  realm_id = data.keycloak_realm.scottylabs.id
  name     = "projects"
}
