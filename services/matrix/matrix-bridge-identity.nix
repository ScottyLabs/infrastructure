# Deploy Keycloak-linked Discord/Slack IDs for cross-platform @mentions on mautrix bridges.
{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.matrix;
in
{
  options.scottylabs.matrix.bridgeIdentityMapFile = lib.mkOption {
    type = lib.types.path;
    default = ./bridge-identity-map.json;
    description = ''
      JSON map of discord_id ↔ slack_user_id for members with both IdP links.
      Regenerate with: governance generate-bridge-identity-map (KEYCLOAK_* required).
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.etc."mautrix-bridge/identity-map.json" = {
      source = cfg.bridgeIdentityMapFile;
      mode = "0444";
    };

    systemd.services.mautrix-slack.serviceConfig.Environment = lib.mkAfter [
      "BRIDGE_IDENTITY_MAP_PATH=/etc/mautrix-bridge/identity-map.json"
    ];

    systemd.services.mautrix-discord.serviceConfig.Environment = lib.mkAfter [
      "BRIDGE_IDENTITY_MAP_PATH=/etc/mautrix-bridge/identity-map.json"
    ];
  };
}
