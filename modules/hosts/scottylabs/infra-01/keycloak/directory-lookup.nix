let
  scottylabs = "\${data.keycloak_realm.scottylabs.id}";
in
{
  perSystem = _: {
    terranix.terranixConfigurations.keycloak.modules = [
      {
        data.keycloak_openid_client.scottylabs_realm_management = {
          realm_id = scottylabs;
          client_id = "realm-management";
        };

        # Senate's Google Sheet checks users' colleges through the admin API
        resource.keycloak_openid_client.directory_lookup = {
          realm_id = scottylabs;
          client_id = "directory-lookup";
          name = "Directory Lookup";
          description = "Used by Senate's Google Sheet";
          access_type = "CONFIDENTIAL";
          service_accounts_enabled = true;
          standard_flow_enabled = false;
          direct_access_grants_enabled = false;
        };

        resource.keycloak_openid_client_service_account_role.directory_lookup = {
          realm_id = scottylabs;
          service_account_user_id = "\${keycloak_openid_client.directory_lookup.service_account_user_id}";
          client_id = "\${data.keycloak_openid_client.scottylabs_realm_management.id}";
          role = "view-users";
        };

        # Grant admin API access
        resource.keycloak_openid_client_default_scopes.directory_lookup = {
          realm_id = scottylabs;
          client_id = "\${keycloak_openid_client.directory_lookup.id}";
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
      }
    ];
  };
}
