let
  labrador = "\${data.keycloak_realm.labrador.id}";
in
{
  perSystem = _: {
    terranix.terranixConfigurations.keycloak.modules = [
      {
        # Realm managed by goldador
        data.keycloak_realm.labrador.realm = "labrador";
        data.keycloak_openid_client.labrador_realm_management = {
          realm_id = labrador;
          client_id = "realm-management";
        };

        resource.keycloak_openid_client.labrador_identity_links = {
          realm_id = labrador;
          client_id = "identity-links";
          name = "Identity links";
          access_type = "CONFIDENTIAL";
          service_accounts_enabled = true;
          standard_flow_enabled = false;
          direct_access_grants_enabled = false;
        };

        # view-users covers /users/{id}/federated-identity and idpAlias user search
        resource.keycloak_openid_client_service_account_role.labrador_identity_links = {
          for_each = ''''${toset(["view-users", "view-identity-providers"])}'';
          realm_id = labrador;
          service_account_user_id = "\${keycloak_openid_client.labrador_identity_links.service_account_user_id}";
          client_id = "\${data.keycloak_openid_client.labrador_realm_management.id}";
          role = "\${each.value}";
        };

        # Grant admin API access
        resource.keycloak_openid_client_default_scopes.labrador_identity_links = {
          realm_id = labrador;
          client_id = "\${keycloak_openid_client.labrador_identity_links.id}";
          default_scopes = [
            "acr"
            "basic"
            "email"
            "kc-admin-api"
            "profile"
            "roles"
            "service_account"
            "web-origins"
          ];
        };

        output.labrador_identity_links_client_secret = {
          value = "\${keycloak_openid_client.labrador_identity_links.client_secret}";
          sensitive = true;
        };
      }
    ];
  };
}
