{ config, ... }:
{
  flake.modules.nixos.infra-01-ai-gateway =
    {
      config,
      inputs,
      ...
    }:

    {
      imports = [
        inputs.llm-pkgs.nixosModules.cliproxyapi
      ];

      age.secrets.cli-proxy-api.file = ../../../secrets/infra-01/cli-proxy-api.age;

      services.cliproxyapi = {
        enable = true;
        settings = {
          host = "127.0.0.1";
          port = 8317;
          api-keys = [ { _secret = "/run/secrets/cli-proxy-api-key"; } ];
          remote-management = {
            allow-remote = false;
            disable-control-panel = true;
            secret-key._secret = config.age.secrets.cli-proxy-api.path;
          };
        };
      };

      services.vault.agents.files.settings.template = [
        {
          contents = ''{{ with secret "secret/data/infra/cli-proxy-api-key" }}{{ .Data.data.API_KEY }}{{ end }}'';
          destination = "/run/secrets/cli-proxy-api-key";
          perms = "0400";
        }
      ];

      systemd.services.cliproxyapi = {
        after = [ "vault-agent-files.service" ];
        wants = [ "vault-agent-files.service" ];
      };

      systemd.services.litellm.vault.infraSecrets = {
        master = {
          path = "litellm-master-key";
          key = "MASTER_KEY";
        };
        salt = {
          path = "litellm-salt-key";
          key = "SALT_KEY";
        };
        oidc = {
          path = "litellm-oidc";
          key = "CLIENT_SECRET";
        };
        cliproxy = {
          path = "cli-proxy-api-key";
          key = "API_KEY";
        };
      };

      scottylabs.ai-gateway.litellm = {
        enable = true;
        masterKeyFile = "/run/credentials/litellm.service/master";
        saltKeyFile = "/run/credentials/litellm.service/salt";
        oidcClientSecretFile = "/run/credentials/litellm.service/oidc";
        cliProxyApiKeyFile = "/run/credentials/litellm.service/cliproxy";
        models =
          let
            passthrough = id: {
              name = id;
              upstream = "openai/${id}";
            };
          in
          map passthrough [
            "claude-opus-4-8"
            "claude-opus-4-7"
            "claude-opus-4-6"
            "claude-opus-4-5-20251101"
            "claude-opus-4-1-20250805"
            "claude-fable-5"
            "claude-sonnet-5"
            "claude-sonnet-4-6"
            "claude-sonnet-4-5-20250929"
            "claude-haiku-4-5-20251001"
            "gpt-5.6-sol"
            "gpt-5.6-terra"
            "gpt-5.6-luna"
            "gpt-5.5"
            "gpt-5.4"
            "gpt-5.4-mini"
            "codex-auto-review"
          ];
      };
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.litellm = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/litellm.tfstate";
            dns.litellm = {
              host = "infra-01";
              type = "CNAME";
              comment = "LiteLLM AI gateway fronting cli-proxy-api";
            };
            resource.keycloak_openid_client.litellm = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "litellm";
              name = "LiteLLM";
              enabled = true;
              access_type = "CONFIDENTIAL";
              standard_flow_enabled = true;
              direct_access_grants_enabled = false;
              valid_redirect_uris = [ "https://litellm.scottylabs.org/sso/callback" ];
            };

            resource.keycloak_openid_group_membership_protocol_mapper.litellm_groups = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "\${keycloak_openid_client.litellm.id}";
              name = "groups";
              claim_name = "groups";
              full_path = true;
            };

            resource.random_password = {
              litellm_master_key = {
                length = 48;
                special = false;
              };
              litellm_salt_key = {
                length = 48;
                special = false;
              };
              cli_proxy_api_key = {
                length = 48;
                special = false;
              };
            };

            resource.vault_kv_secret_v2 = {
              litellm_oidc = {
                mount = "secret";
                name = "infra/litellm-oidc";
                data_json = "\${jsonencode({ CLIENT_SECRET = keycloak_openid_client.litellm.client_secret })}";
              };
              litellm_master_key = {
                mount = "secret";
                name = "infra/litellm-master-key";
                data_json = ''''${jsonencode({ MASTER_KEY = "sk-''${random_password.litellm_master_key.result}" })}'';
              };
              litellm_salt_key = {
                mount = "secret";
                name = "infra/litellm-salt-key";
                data_json = "\${jsonencode({ SALT_KEY = random_password.litellm_salt_key.result })}";
              };
              cli_proxy_api_key = {
                mount = "secret";
                name = "infra/cli-proxy-api-key";
                data_json = "\${jsonencode({ API_KEY = random_password.cli_proxy_api_key.result })}";
              };
            };
          }
        ];
      };
    };
}
