{ config, ... }:
{
  flake.modules.nixos.matrix =
    {
      config,
      lib,
      ...
    }:

    let
      cfg = config.scottylabs.matrix;
    in
    {

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
        # Give Synapse both bridge registration groups
        systemd.services.matrix-synapse.serviceConfig.SupplementaryGroups = lib.mkForce [
          "mautrix-discord"
          "mautrix-slack-registration"
        ];
      };
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.matrix = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/matrix.tfstate";
            dns = {
              "@" = {
                zone = "doggylabs.org";
                host = "infra-01";
                type = "CNAME";
                comment = "Matrix homeserver (Synapse)";
              };
              matrix = {
                zone = "doggylabs.org";
                host = "infra-01";
                type = "CNAME";
                comment = "Matrix homeserver (Synapse)";
              };
            };
          }
        ];
      };
    };
}
