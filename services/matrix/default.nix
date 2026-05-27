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
}
