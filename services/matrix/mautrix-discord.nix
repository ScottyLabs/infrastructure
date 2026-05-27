{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.matrix;
  bridge = cfg.bridges.discord;
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
  options.scottylabs.matrix.bridges.discord = {
    enable = lib.mkEnableOption "mautrix-discord bridge";

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
    services.mautrix-discord = {
      enable = true;
      environmentFile = bridge.environmentFile;
      settings = {
        homeserver = {
          address = "http://127.0.0.1:${toString cfg.synapse.listenPort}";
          domain = cfg.domain;
        };
        appservice = {
          database = {
            type = "postgres";
            uri = "postgresql:///mautrix-discord?host=/run/postgresql";
          };
          bot = {
            username = "discord";
            displayname = "Discord Bridge";
          };
        };
        bridge = {
          double_puppet_server_map = {
            "${cfg.domain}" = "https://${cfg.matrixDomain}";
          };
          login_shared_secret_map = {
            "${cfg.domain}" = "$DOUBLE_PUPPET_SECRET";
          };
          delete_portal_on_channel_delete = true;
          enable_webhook_avatars = true;
          encryption = {
            allow = true;
            default = true;
            allow_key_sharing = true;
            pickle_key = "generate";
          };
          relay = {
            enabled = false;
            admin_only = false;
          };
          permissions = bridgePermissions;
        };
      };
    };

    scottylabs.postgresql.databases = [ "mautrix-discord" ];
  };
}
