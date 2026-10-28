{ inputs, ... }:
{
  flake.modules.nixos.scottylabs-infra-01-matrix-bridge-identity =
    {
      config,
      lib,
      ...
    }:

    let
      cfg = config.scottylabs.matrix;
      identityCfg = cfg.bridgeIdentity;

      inherit (builtins.fromJSON (builtins.readFile "${inputs.governance}/generated/data.json")) tech;
      keycloakUrl = tech.keycloak.url;
      keycloakRealm = tech.keycloak.realm;
      matrixDomain = tech.communication.matrix_domain or cfg.domain;
    in
    {
      options.scottylabs.matrix.bridgeIdentity = {
        enable = lib.mkEnableOption "Discord/Slack identity link resolution from Keycloak for bridge mentions";

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Environment file with KEYCLOAK_CLIENT_ID and KEYCLOAK_CLIENT_SECRET (governance service account).
          '';
        };

        refreshInterval = lib.mkOption {
          type = lib.types.str;
          default = "60s";
          description = "How long bridge identity lookups are cached before re-fetching from Keycloak.";
        };
      };

      config = lib.mkIf (cfg.enable && identityCfg.enable) {
        assertions = [
          {
            assertion = identityCfg.environmentFile != null;
            message = "scottylabs.matrix.bridgeIdentity.environmentFile must be set when bridge identity is enabled.";
          }
          {
            assertion = tech ? keycloak && tech.keycloak ? url && tech.keycloak ? realm;
            message = "governance's generated/data.json must define tech.keycloak.url and tech.keycloak.realm.";
          }
        ];

        systemd.services.mautrix-slack.serviceConfig.EnvironmentFile = lib.mkAfter [
          identityCfg.environmentFile
        ];
        systemd.services.mautrix-slack.serviceConfig.Environment = lib.mkAfter [
          "KEYCLOAK_URL=${keycloakUrl}"
          "KEYCLOAK_REALM=${keycloakRealm}"
          "MATRIX_DOMAIN=${matrixDomain}"
          "BRIDGE_IDENTITY_REFRESH_INTERVAL=${identityCfg.refreshInterval}"
          "GOVERNANCE_DATA_PATH=${inputs.governance}/data"
          "GOVERNANCE_DATA_REFRESH_INTERVAL=${identityCfg.refreshInterval}"
        ];

        systemd.services.mautrix-discord.serviceConfig.EnvironmentFile = lib.mkAfter [
          identityCfg.environmentFile
        ];
        systemd.services.mautrix-discord.serviceConfig.Environment = lib.mkAfter [
          "KEYCLOAK_URL=${keycloakUrl}"
          "KEYCLOAK_REALM=${keycloakRealm}"
          "MATRIX_DOMAIN=${matrixDomain}"
          "BRIDGE_IDENTITY_REFRESH_INTERVAL=${identityCfg.refreshInterval}"
          "GOVERNANCE_DATA_PATH=${inputs.governance}/data"
          "GOVERNANCE_DATA_REFRESH_INTERVAL=${identityCfg.refreshInterval}"
        ];
      };
    };
}
