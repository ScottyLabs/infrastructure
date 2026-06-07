# Keycloak-backed bridge identity lookups for cross-platform @mentions (no static JSON file).
{
  config,
  lib,
  governance,
  ...
}:

let
  cfg = config.scottylabs.matrix;
  identityCfg = cfg.bridgeIdentity;

  org = builtins.fromTOML (builtins.readFile "${governance}/data/org.toml");
  keycloakUrl = org.org.keycloak.url;
  keycloakRealm = org.org.keycloak.realm;
  matrixDomain =
    org.org.communication.matrix_domain or cfg.domain;
in
{
  options.scottylabs.matrix.bridgeIdentity = {
    enable = lib.mkEnableOption ''
      Resolve Discord ↔ Slack identity links from Keycloak at runtime for mautrix bridge mentions.
      Bridges query Keycloak directly with an auto-refreshed in-memory cache (no identity map file).
    '';

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
        assertion = org.org.keycloak ? url && org.org.keycloak ? realm;
        message = "governance org.toml must define org.keycloak.url and org.keycloak.realm.";
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
    ];

    systemd.services.mautrix-discord.serviceConfig.EnvironmentFile = lib.mkAfter [
      identityCfg.environmentFile
    ];
    systemd.services.mautrix-discord.serviceConfig.Environment = lib.mkAfter [
      "KEYCLOAK_URL=${keycloakUrl}"
      "KEYCLOAK_REALM=${keycloakRealm}"
      "MATRIX_DOMAIN=${matrixDomain}"
      "BRIDGE_IDENTITY_REFRESH_INTERVAL=${identityCfg.refreshInterval}"
    ];
  };
}
