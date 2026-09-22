let
  # CMU Entra tenant
  cmuEntra = "https://login.microsoftonline.com/e36ee38f-91b8-4dca-9b13-caa5360c9714";

  # claim -> user attribute importer for an OIDC IdP
  oidcMapper = alias: attr: claim: {
    realm = "\${data.keycloak_realm.scottylabs.id}";
    name = attr;
    identity_provider_alias = alias;
    identity_provider_mapper = "oidc-user-attribute-idp-mapper";
    extra_config = {
      inherit claim;
      "user.attribute" = attr;
      syncMode = "FORCE";
    };
  };

  oidcIdp =
    args:
    {
      realm = "\${data.keycloak_realm.scottylabs.id}";
      link_only = true;
      hide_on_login_page = true;
      store_token = true;
      sync_mode = "IMPORT";
      validate_signature = true;
      extra_config.clientAuthMethod = "client_secret_post";
    }
    // args;

  # Forgejo instance as an OIDC IdP
  forgejoIdp =
    { base, ... }@args:
    oidcIdp (
      removeAttrs args [ "base" ]
      // {
        authorization_url = "${base}/login/oauth/authorize";
        token_url = "${base}/login/oauth/access_token";
        user_info_url = "${base}/login/oauth/userinfo";
        jwks_url = "${base}/login/oauth/keys";
        issuer = base;
      }
    );
in
{
  perSystem = _: {
    terranix.terranixConfigurations.keycloak.modules = [
      {
        data.vault_kv_secret_v2.keycloak_idp = {
          mount = "secret";
          name = "infra/keycloak-idp";
        };

        data.vault_kv_secret_v2.forgejo_idp = {
          mount = "secret";
          name = "infra/forgejo-idp";
        };

        resource.keycloak_oidc_identity_provider.slack = oidcIdp {
          alias = "slack";
          display_name = "Slack";
          client_id = "3505580336.8910681007893";
          client_secret = "\${data.vault_kv_secret_v2.keycloak_idp.data[\"SLACK_CLIENT_SECRET\"]}";
          authorization_url = "https://slack.com/openid/connect/authorize";
          token_url = "https://slack.com/api/openid.connect.token";
          user_info_url = "https://slack.com/api/openid.connect.userInfo";
          jwks_url = "https://slack.com/openid/connect/keys";
          issuer = "https://slack.com";
        };

        resource.keycloak_oidc_google_identity_provider.google = {
          realm = "\${data.keycloak_realm.scottylabs.id}";
          link_only = true;
          hide_on_login_page = true;
          store_token = true;
          sync_mode = "IMPORT";
          default_scopes = "openid profile email";
          client_id = "193590704321-04lnrs4bkqn7jmpva58g4utnqao7bgio.apps.googleusercontent.com";
          client_secret = "\${data.vault_kv_secret_v2.keycloak_idp.data[\"GOOGLE_CLIENT_SECRET\"]}";
        };

        resource.keycloak_oidc_identity_provider.cmu_git = forgejoIdp {
          alias = "cmu-dev";
          display_name = "cmu.dev";
          base = "https://git.cmu.dev";
          client_id = "\${data.vault_kv_secret_v2.forgejo_idp.data[\"CLIENT_ID\"]}";
          client_secret = "\${data.vault_kv_secret_v2.forgejo_idp.data[\"CLIENT_SECRET\"]}";
          default_scopes = "openid profile email";
        };

        resource.keycloak_oidc_identity_provider.cmu = {
          realm = "\${data.keycloak_realm.scottylabs.id}";
          alias = "cmu";
          display_name = "CMU";
          store_token = true;
          trust_email = true;
          sync_mode = "IMPORT";
          first_broker_login_flow_alias = "Auto-link LDAP users";
          post_broker_login_flow_alias = "SAML post login";
          backchannel_supported = false;
          validate_signature = true;
          client_id = "9e6c9456-6584-42aa-8d2a-1ba4e45dd0a6";
          client_secret = "\${data.vault_kv_secret_v2.keycloak_idp.data[\"CMU_CLIENT_SECRET\"]}";
          authorization_url = "${cmuEntra}/oauth2/v2.0/authorize";
          token_url = "${cmuEntra}/oauth2/v2.0/token";
          logout_url = "${cmuEntra}/oauth2/v2.0/logout";
          user_info_url = "https://graph.microsoft.com/oidc/userinfo";
          jwks_url = "${cmuEntra}/discovery/v2.0/keys";
          issuer = "${cmuEntra}/v2.0";
          default_scopes = "openid profile email offline_access";
          extra_config = {
            clientAuthMethod = "client_secret_post";
            pkceEnabled = "true";
            pkceMethod = "S256";
            # auto-link keys on the localpart, so reject non-Andrew usernames
            filteredByClaim = "true";
            claimFilterName = "preferred_username";
            claimFilterValue = "(?i)[^@]+@andrew\\.cmu\\.edu";
          };
        };

        resource.keycloak_saml_identity_provider.cmu_saml = {
          realm = "\${data.keycloak_realm.scottylabs.id}";
          alias = "cmu-saml";
          display_name = "CMU SAML";
          enabled = false;
          store_token = false;
          trust_email = true;
          hide_on_login_page = true;
          sync_mode = "FORCE";
          gui_order = "7";
          first_broker_login_flow_alias = "Auto-link LDAP users";
          post_broker_login_flow_alias = "SAML post login";
          entity_id = "https://idp.scottylabs.org/realms/scottylabs";
          single_sign_on_service_url = "https://login.cmu.edu/idp/profile/SAML2/POST/SSO";
          name_id_policy_format = "Transient";
          principal_type = "FRIENDLY_ATTRIBUTE";
          principal_attribute = "eduPersonPrincipalName";
          validate_signature = true;
          want_authn_requests_signed = true;
          signature_algorithm = "RSA_SHA256";
          xml_sign_key_info_key_name_transformer = "KEY_ID";
          post_binding_authn_request = true;
          post_binding_response = true;
          extra_config = {
            idpEntityId = "https://login.cmu.edu/idp/shibboleth";
            # signing keys from metadata, no pinned cert
            useMetadataDescriptorUrl = "true";
            metadataDescriptorUrl = "https://login.cmu.edu/idp/shibboleth";
            allowCreate = "true";
            attributeConsumingServiceIndex = "0";
          };
        };

        # TODO: discord IdP unavailable without the keycloak-discord server plugin

        resource.keycloak_custom_identity_provider_mapper = {
          slack_id =
            oidcMapper "\${keycloak_oidc_identity_provider.slack.alias}" "slack_id"
              "https://slack\\.com/user_id";
          slack_email = oidcMapper "\${keycloak_oidc_identity_provider.slack.alias}" "slack_email" "email";
          slack_name = oidcMapper "\${keycloak_oidc_identity_provider.slack.alias}" "slack_name" "name";
          google_id = oidcMapper "\${keycloak_oidc_google_identity_provider.google.alias}" "google_id" "sub";
          google_email =
            oidcMapper "\${keycloak_oidc_google_identity_provider.google.alias}" "google_email"
              "email";
          google_name =
            oidcMapper "\${keycloak_oidc_google_identity_provider.google.alias}" "google_name"
              "name";
          cmudev_id = {
            realm = "\${data.keycloak_realm.scottylabs.id}";
            name = "cmudev_id";
            identity_provider_alias = "\${keycloak_oidc_identity_provider.cmu_git.alias}";
            identity_provider_mapper = "oidc-user-attribute-idp-mapper";
            extra_config = {
              claim = "sub";
              "user.attribute" = "cmudev_id";
              syncMode = "FORCE";
            };
          };
          cmudev_username = {
            realm = "\${data.keycloak_realm.scottylabs.id}";
            name = "cmudev_username";
            identity_provider_alias = "\${keycloak_oidc_identity_provider.cmu_git.alias}";
            identity_provider_mapper = "oidc-user-attribute-idp-mapper";
            extra_config = {
              claim = "preferred_username";
              "user.attribute" = "cmudev_username";
              syncMode = "FORCE";
            };
          };
          cmudev_email = {
            realm = "\${data.keycloak_realm.scottylabs.id}";
            name = "cmudev_email";
            identity_provider_alias = "\${keycloak_oidc_identity_provider.cmu_git.alias}";
            identity_provider_mapper = "oidc-user-attribute-idp-mapper";
            extra_config = {
              claim = "email";
              "user.attribute" = "cmudev_email";
              syncMode = "FORCE";
            };
          };
          cmudev_name = {
            realm = "\${data.keycloak_realm.scottylabs.id}";
            name = "cmudev_name";
            identity_provider_alias = "\${keycloak_oidc_identity_provider.cmu_git.alias}";
            identity_provider_mapper = "oidc-user-attribute-idp-mapper";
            extra_config = {
              claim = "name";
              "user.attribute" = "cmudev_name";
              syncMode = "FORCE";
            };
          };
          cmu_username = {
            realm = "\${data.keycloak_realm.scottylabs.id}";
            name = "username";
            identity_provider_alias = "\${keycloak_oidc_identity_provider.cmu.alias}";
            identity_provider_mapper = "oidc-username-idp-mapper";
            extra_config = {
              # andrewid@andrew.cmu.edu -> andrewid, matching LDAP
              template = "$\${CLAIM.preferred_username | localpart}";
              target = "BROKER_USERNAME";
              syncMode = "INHERIT";
            };
          };
          cmu_saml_username = {
            realm = "\${data.keycloak_realm.scottylabs.id}";
            name = "username";
            identity_provider_alias = "\${keycloak_saml_identity_provider.cmu_saml.alias}";
            identity_provider_mapper = "saml-username-idp-mapper";
            extra_config = {
              template = "$\${ATTRIBUTE.urn:oid:1.3.6.1.4.1.5923.1.1.1.6 | localpart}";
              target = "BROKER_USERNAME";
              syncMode = "INHERIT";
            };
          };
        };
      }
    ];
  };
}
