let
  master = "\${data.keycloak_realm.master.id}";
  scottylabs = "https://idp.scottylabs.org/realms/scottylabs";
in
{
  perSystem = _: {
    terranix.terranixConfigurations.keycloak.modules = [
      {
        data.keycloak_realm.master.realm = "master";
        data.keycloak_role.master_admin = {
          realm_id = master;
          name = "admin";
        };

        # Keycloak provider credentials for terranix
        resource.keycloak_openid_client.terranix = {
          realm_id = master;
          client_id = "terranix";
          name = "terranix";
          access_type = "CONFIDENTIAL";
          service_accounts_enabled = true;
          standard_flow_enabled = false;
          direct_access_grants_enabled = false;
        };

        resource.keycloak_openid_client_service_account_realm_role.terranix_admin = {
          realm_id = master;
          service_account_user_id = "\${keycloak_openid_client.terranix.service_account_user_id}";
          role = "\${data.keycloak_role.master_admin.name}";
        };

        resource.vault_kv_secret_v2.keycloak_terranix = {
          mount = "secret";
          name = "infra/keycloak-terranix";
          data_json = "\${jsonencode({ CLIENT_ID = keycloak_openid_client.terranix.client_id, CLIENT_SECRET = keycloak_openid_client.terranix.client_secret })}";
        };

        # Admin console login for devops admins
        resource.keycloak_openid_client.keycloak_master = {
          realm_id = "\${data.keycloak_realm.scottylabs.id}";
          client_id = "keycloak-master";
          name = "Keycloak admin console";
          access_type = "CONFIDENTIAL";
          standard_flow_enabled = true;
          direct_access_grants_enabled = false;
          valid_redirect_uris = [ "https://idp.scottylabs.org/realms/master/broker/scottylabs/endpoint" ];
        };

        resource.keycloak_openid_group_membership_protocol_mapper.keycloak_master_groups = {
          realm_id = "\${data.keycloak_realm.scottylabs.id}";
          client_id = "\${keycloak_openid_client.keycloak_master.id}";
          name = "groups";
          claim_name = "groups";
          full_path = true;
        };

        resource.keycloak_oidc_identity_provider.master_scottylabs = {
          realm = master;
          alias = "scottylabs";
          display_name = "ScottyLabs";
          authorization_url = "${scottylabs}/protocol/openid-connect/auth";
          token_url = "${scottylabs}/protocol/openid-connect/token";
          user_info_url = "${scottylabs}/protocol/openid-connect/userinfo";
          jwks_url = "${scottylabs}/protocol/openid-connect/certs";
          issuer = scottylabs;
          client_id = "\${keycloak_openid_client.keycloak_master.client_id}";
          client_secret = "\${keycloak_openid_client.keycloak_master.client_secret}";
          default_scopes = "openid profile email";
          validate_signature = true;
          trust_email = true;
          store_token = false;
          sync_mode = "FORCE";
          extra_config = {
            clientAuthMethod = "client_secret_post";
            allowAdminRoleMapping = "true";
          };
        };

        resource.keycloak_custom_identity_provider_mapper.master_devops_admin = {
          realm = master;
          name = "devops-admin";
          identity_provider_alias = "\${keycloak_oidc_identity_provider.master_scottylabs.alias}";
          identity_provider_mapper = "oidc-advanced-role-idp-mapper";
          extra_config = {
            claims = builtins.toJSON [
              {
                key = "groups";
                value = "/projects/devops/admins";
              }
            ];
            "are.claim.values.regex" = "false";
            role = "\${data.keycloak_role.master_admin.name}";
            syncMode = "FORCE";
          };
        };
      }
    ];
  };
}
