{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.matrix;
  bridge = cfg.bridges.slack;
  bridgePermissions =
    {
      "*" = "user";
      "${cfg.domain}" = "user";
    }
    // lib.listToAttrs (map (uid: {
      name = uid;
      value = "admin";
    }) bridge.adminUsers);
in
{
  imports = [ ./nixos-mautrix-slack.nix ];

  options.scottylabs.matrix.bridges.slack = {
    enable = lib.mkEnableOption "mautrix-slack bridge";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to env file containing DOUBLE_PUPPET_SECRET and other bridge-runtime values.";
    };

    adminUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Matrix user IDs granted bridge admin permissions.";
    };
  };

  config = lib.mkIf (cfg.enable && bridge.enable) {
    services.mautrix-slack = {
      enable = true;
      environmentFile = bridge.environmentFile;
      settings = {
        homeserver = {
          address = "http://127.0.0.1:${toString cfg.synapse.listenPort}";
          domain = cfg.domain;
        };
        database = {
          type = "postgres";
          uri = "postgresql:///mautrix-slack?host=/run/postgresql";
        };
        appservice = {
          bot = {
            username = "slack";
            displayname = "Slack Bridge";
          };
        };
        bridge = {
          double_puppet_server_map = {
            "${cfg.domain}" = "https://${cfg.matrixDomain}";
          };
          login_shared_secret_map = {
            "${cfg.domain}" = "$DOUBLE_PUPPET_SECRET";
          };
          encryption = {
            allow = true;
            default = false;
          };
          relay = {
            enabled = false;
            admin_only = false;
          };
          permissions = bridgePermissions;
        };
      };
    };

    scottylabs.postgresql.databases = [ "mautrix-slack" ];
  };
}
