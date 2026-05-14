resource "keycloak_openid_client" "grafana" {
  realm_id  = data.keycloak_realm.scottylabs.id
  client_id = "grafana"
  name      = "Grafana"

  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://grafana.scottylabs.org/login/generic_oauth"
  ]
}

resource "keycloak_openid_group_membership_protocol_mapper" "grafana_groups" {
  realm_id   = data.keycloak_realm.scottylabs.id
  client_id  = keycloak_openid_client.grafana.id
  name       = "groups"
  claim_name = "groups"
  full_path  = true
}

resource "vault_kv_secret_v2" "grafana_oidc" {
  mount = "secret"
  name  = "infra/grafana-oidc"

  data_json = jsonencode({
    CLIENT_SECRET = keycloak_openid_client.grafana.client_secret
  })
}
