{ inputs, ... }:
{
  flake.modules.nixos.litellm =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.ai-gateway.litellm;
      keycloakRealmBase = "${cfg.keycloakIssuerBase}/realms/${cfg.keycloakRealm}";
      databaseUrl = "postgresql://litellm@localhost/litellm?host=/run/postgresql";
      composeEnvScript = pkgs.writeShellScript "compose-litellm-env" ''
        set -eu
        umask 0077
        {
          printf 'LITELLM_MASTER_KEY=%s\n' "$(cat ${cfg.masterKeyFile})"
          printf 'LITELLM_SALT_KEY=%s\n' "$(cat ${cfg.saltKeyFile})"
          printf 'GENERIC_CLIENT_SECRET=%s\n' "$(cat ${cfg.oidcClientSecretFile})"
          printf 'CLI_PROXY_API_KEY=%s\n' "$(cat ${cfg.cliProxyApiKeyFile})"
        } > ${cfg.runtimeEnvFile}
      '';
    in
    {
      imports = [ inputs.llm-pkgs.nixosModules.litellm ];

      options.scottylabs.ai-gateway.litellm = {
        enable = lib.mkEnableOption "LiteLLM proxy fronting cli-proxy-api";

        domain = lib.mkOption {
          type = lib.types.str;
          default = "litellm.scottylabs.org";
          description = "Public hostname Caddy reverse-proxies to LiteLLM.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "LiteLLM HTTP listen address.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 4000;
          description = "LiteLLM HTTP listen port.";
        };

        keycloakIssuerBase = lib.mkOption {
          type = lib.types.str;
          default = "https://idp.scottylabs.org";
          description = "Keycloak base URL without the realm path.";
        };

        keycloakRealm = lib.mkOption {
          type = lib.types.str;
          default = "scottylabs";
          description = "Keycloak realm hosting the LiteLLM OIDC client.";
        };

        adminGroupPath = lib.mkOption {
          type = lib.types.str;
          default = "/projects/devops/admins";
          description = ''
            Full Keycloak group path whose members get the LiteLLM `proxy_admin`
            role. Users outside this group are denied login (no `internal_user`
            fallback). Path must match the `full_path = true` group claim shape.
          '';
        };

        masterKeyFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to a file (readable by the litellm user) containing the raw
            LITELLM_MASTER_KEY value. The master key bypasses virtual-key auth
            and is used by governance tfgen to provision team keys.
          '';
        };

        saltKeyFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to a file (readable by the litellm user) containing the raw
            LITELLM_SALT_KEY value used to hash virtual keys in the database.
            Rotating this key invalidates every existing virtual key.
          '';
        };

        oidcClientSecretFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to a file containing the Keycloak OIDC client_secret for LiteLLM.";
        };

        cliProxyApiKeyFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to a file (readable by the litellm user) containing the
            bearer token cli-proxy-api expects on inbound model requests.
            The same secret must be present in
            `scottylabs.cli-proxy-api.apiKeyFiles` on the backend host.
          '';
        };

        runtimeEnvFile = lib.mkOption {
          type = lib.types.path;
          default = "/run/litellm/env";
          description = "Composed KEY=VALUE env file consumed by the litellm service.";
        };

        cliProxyApiUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:8317/v1";
          description = "OpenAI-compatible base URL of the cli-proxy-api backend.";
        };

        models = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Public model name advertised by LiteLLM.";
                };
                upstream = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    LiteLLM model identifier (e.g. `openai/gpt-4o`,
                    `anthropic/claude-3-5-sonnet-20241022`). The prefix selects
                    the chat-completion adapter LiteLLM uses to call the
                    cli-proxy-api backend.
                  '';
                };
              };
            }
          );
          default = [ ];
          description = ''
            Model list routed through cli-proxy-api. Empty by default; populate
            per-host once the backend's model coverage is finalized.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = ''
            Extra `services.litellm.settings` merged on top of the derived
            defaults (model_list, general_settings.database_url, ...).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        users.users.litellm = {
          isSystemUser = true;
          group = "litellm";
          home = "/var/lib/litellm";
        };
        users.groups.litellm = { };

        services.litellm = {
          enable = true;
          inherit (cfg) host port;
          environmentFile = cfg.runtimeEnvFile;

          environment = {
            SCARF_NO_ANALYTICS = "True";
            DO_NOT_TRACK = "True";
            ANONYMIZED_TELEMETRY = "False";

            PROXY_BASE_URL = "https://${cfg.domain}";
            DATABASE_URL = databaseUrl;

            GENERIC_CLIENT_ID = "litellm";
            GENERIC_AUTHORIZATION_ENDPOINT = "${keycloakRealmBase}/protocol/openid-connect/auth";
            GENERIC_TOKEN_ENDPOINT = "${keycloakRealmBase}/protocol/openid-connect/token";
            GENERIC_USERINFO_ENDPOINT = "${keycloakRealmBase}/protocol/openid-connect/userinfo";
            GENERIC_SCOPE = "openid email profile";
            GENERIC_INCLUDE_CLIENT_CREDENTIALS = "false";

            GENERIC_USER_ID_ATTRIBUTE = "sub";
            GENERIC_USER_EMAIL_ATTRIBUTE = "email";
            GENERIC_USER_DISPLAY_NAME_ATTRIBUTE = "name";
            GENERIC_USER_FIRST_NAME_ATTRIBUTE = "given_name";
            GENERIC_USER_LAST_NAME_ATTRIBUTE = "family_name";

            GENERIC_ROLE_MAPPINGS_GROUP_CLAIM = "groups";
            GENERIC_ROLE_MAPPINGS_ROLES = builtins.toJSON {
              proxy_admin = [ cfg.adminGroupPath ];
            };
            GENERIC_ROLE_MAPPINGS_DEFAULT_ROLE = "internal_user";

            # Redirect the login form straight to Keycloak
            AUTO_REDIRECT_UI_LOGIN_TO_SSO = "true";
          };

          settings = lib.recursiveUpdate {
            model_list = map (m: {
              model_name = m.name;
              litellm_params = {
                model = m.upstream;
                api_base = cfg.cliProxyApiUrl;
                api_key = "os.environ/CLI_PROXY_API_KEY";
              };
            }) cfg.models;

            general_settings = {
              database_url = databaseUrl;
              allow_user_auth = true;
              ui_access_mode = {
                type = "restricted_sso_group";
                restricted_sso_group = cfg.adminGroupPath;
                sso_group_jwt_field = "groups";
              };
            };

            litellm_settings = {
              drop_params = true;
              callbacks = [ "prometheus" ];
            };
          } cfg.settings;
        };

        systemd.services.litellm = {
          after = [
            "bao-agent.service"
            "postgresql.service"
          ];
          wants = [
            "bao-agent.service"
            "postgresql.service"
          ];
          serviceConfig = {
            DynamicUser = lib.mkForce false;
            User = "litellm";
            Group = "litellm";
            EnvironmentFile = lib.mkForce [ "-${cfg.runtimeEnvFile}" ];
            ExecStartPre = lib.mkBefore [ composeEnvScript ];
          };
        };

        services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
          redir / /ui/
          reverse_proxy ${cfg.host}:${toString cfg.port}
        '';

        scottylabs.postgresql.databases = [ "litellm" ];
      };
    };
}
