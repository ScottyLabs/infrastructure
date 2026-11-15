{ config, ... }:
{
  flake.modules.nixos.scottylabs-infra-01-collar-broker =
    {
      inputs,
      pkgs,
      ...
    }:
    {
      systemd.services.collar-broker = {
        description = "Collar Forgejo token broker";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        vault.infraSecrets.client-secret = {
          path = "collar-broker";
          key = "CLIENT_SECRET";
        };

        serviceConfig = {
          ExecStart = "${
            inputs.collar.packages.${pkgs.stdenv.hostPlatform.system}.collar
          }/bin/collar-broker --listen 127.0.0.1:8094 --client-secret-file /run/credentials/collar-broker.service/client-secret";
          DynamicUser = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      services.caddy.virtualHosts."collar-broker.scottylabs.org".extraConfig = ''
        reverse_proxy 127.0.0.1:8094 {
          transport http {
            dial_timeout 5s
            response_header_timeout 40s
          }
        }
      '';
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.collar-broker = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/collar-broker.tfstate";

            dns.collar-broker = {
              name = "collar-broker";
              tunnel = "scottylabs-infra-01";
              comment = "Collar Forgejo token broker";
            };

            resource.keycloak_openid_client.collar_broker = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "collar-broker";
              name = "Collar Forgejo token broker";
              access_type = "CONFIDENTIAL";
              standard_flow_enabled = false;
              direct_access_grants_enabled = false;
              service_accounts_enabled = false;
              valid_redirect_uris = [ ];
              web_origins = [ ];
              extra_config = {
                "external.token.enabled" = "true";
                "external.token.idp" = "cmu-dev";
              };
            };

            resource.vault_kv_secret_v2.collar_broker = {
              mount = "secret";
              name = "infra/collar-broker";
              data_json = "\${jsonencode({ CLIENT_SECRET = keycloak_openid_client.collar_broker.client_secret })}";
            };
          }
        ];
      };
    };
}
