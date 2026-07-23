let
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

  # GitHub /user json field -> user attribute importer
  githubMapper = attr: field: {
    realm = "\${data.keycloak_realm.scottylabs.id}";
    name = attr;
    identity_provider_alias = "github";
    identity_provider_mapper = "github-user-attribute-mapper";
    extra_config = {
      jsonField = field;
      userAttribute = attr;
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

        resource.keycloak_oidc_identity_provider.codeberg = forgejoIdp {
          alias = "codeberg";
          display_name = "Codeberg";
          base = "https://codeberg.org";
          client_id = "63438ffe-847f-4467-a3ac-b795bc56fd5e";
          client_secret = "\${data.vault_kv_secret_v2.keycloak_idp.data[\"CODEBERG_CLIENT_SECRET\"]}";
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

        # TODO: https://codeberg.org/ScottyLabs/infrastructure/issues/83
        # TODO: discord IdP unavailable without the keycloak-discord server plugin

        resource.keycloak_custom_identity_provider_mapper = {
          codeberg_id = oidcMapper "\${keycloak_oidc_identity_provider.codeberg.alias}" "codeberg_id" "sub";
          codeberg_username =
            oidcMapper "\${keycloak_oidc_identity_provider.codeberg.alias}" "codeberg_username"
              "preferred_username";
          codeberg_email =
            oidcMapper "\${keycloak_oidc_identity_provider.codeberg.alias}" "codeberg_email"
              "email";
          codeberg_name =
            oidcMapper "\${keycloak_oidc_identity_provider.codeberg.alias}" "codeberg_name"
              "name";
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
          github_id = githubMapper "github_id" "id";
          github_username = githubMapper "github_username" "login";
          github_email = githubMapper "github_email" "email";
          github_name = githubMapper "github_name" "name";
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
        };
      }
    ];
  };
}
