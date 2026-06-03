{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.matrix;
  bridge = cfg.bridges.discord;
  # Relay/webhook Matrix→Discord posts cannot start threads upstream; use any logged-in bridge user.
  mautrixDiscord = pkgs.mautrix-discord.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../patches/mautrix-discord-relay-threads.patch
      ../../patches/mautrix-discord-set-relay-automation.patch
      ../../patches/mautrix-discord-embed-link-url.patch
      ../../patches/mautrix-discord-ping-prefix.patch
      ../../patches/mautrix-discord-preserve-topic.patch
      ../../patches/mautrix-discord-skip-thread-creation-msgs.patch
      ../../patches/mautrix-discord-bridge-identity-pings.patch
      ../../patches/mautrix-discord-bridge-identity-replies.patch
    ];
  });
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
      description = ''
        Path to env file containing DOUBLE_PUPPET_SECRET and AVATAR_PROXY_KEY
        (for relay webhook profile pictures).
      '';
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
      package = mautrixDiscord;
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
          # Matrix ghost display names for relay formatting on mautrix-slack (GlobalName, then username).
          displayname_template = "{{if .Webhook}}Webhook{{else}}{{or .GlobalName .Username}}{{if .Bot}} (bot){{end}}{{end}}";
          double_puppet_server_map = {
            "${cfg.domain}" = "https://${cfg.matrixDomain}";
          };
          login_shared_secret_map = {
            "${cfg.domain}" = "$DOUBLE_PUPPET_SECRET";
          };
          delete_portal_on_channel_delete = true;
          # Slack→Discord relay webhooks need a URL Discord can fetch for Matrix ghost avatars.
          public_address = "https://${cfg.matrixDomain}";
          avatar_proxy_key = "$AVATAR_PROXY_KEY";
          enable_webhook_avatars = true;
          autojoin_thread_on_open = true;
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
