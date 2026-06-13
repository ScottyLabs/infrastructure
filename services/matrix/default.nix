{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.matrix;
in
{
  imports = [
    ./synapse.nix
    ./mautrix-discord.nix
    ./mautrix-slack.nix
    ./matrix-bridge-identity.nix
    ./bridge-media-proxy.nix
    ./well-known.nix
  ];

  options.scottylabs.matrix = {
    enable = lib.mkEnableOption "Matrix homeserver (Synapse) plus bridges and .well-known endpoints";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Server name advertised in the matrix ID (e.g. doggylabs.org).";
    };

    matrixDomain = lib.mkOption {
      type = lib.types.str;
      default = "matrix.${cfg.domain}";
      defaultText = lib.literalExpression ''"matrix.''${config.scottylabs.matrix.domain}"'';
      description = "HTTP endpoint hostname for the homeserver (used by clients and federation).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Both bridge modules set SupplementaryGroups independently; the last import wins
    # without this, leaving Synapse unable to read the other bridge registration file.
    systemd.services.matrix-synapse.serviceConfig.SupplementaryGroups = lib.mkForce [
      "mautrix-discord-registration"
      "mautrix-slack-registration"
    ];
  };
}
