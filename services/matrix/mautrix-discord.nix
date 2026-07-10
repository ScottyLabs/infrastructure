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
  # ScottyLabs fork: vendored bridge v1 + mautrix-go v0.28.0 (same as Slack).
  forkSrc = pkgs.fetchFromGitHub {
    owner = "thesuperRL";
    repo = "mautrix-discord";
    rev = "9131e2570a5150de082519c4a7b33a398c0bfcca";
    hash = "sha256-/RfzwFZjiCCXsPLTwkpL8OqWPMxChBb6ISrn2gsQo1k=";
  };
  mautrixDiscord = pkgs.mautrix-discord.overrideAttrs (old: {
    src = forkSrc;
    version = "0.7.6";
    doInstallCheck = false;
    vendorHash = null;
    goModules = null;
    # fork commit 412df13 vendors deps in-tree; goModules outputHash no longer applies
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
        Path to env file containing DOUBLE_PUPPET_SECRET, AVATAR_PROXY_KEY
        (for relay webhook profile pictures), and DISCORD_RELAY_LOGIN_ID
        (for thread creation and relay operations).
      '';
    };

    adminUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Matrix user IDs granted bridge admin permissions.";
    };

    relay.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable mautrix-discord relay. Required for thread creation by logged-in users
        (webhooks cannot start Discord threads). Requires DISCORD_RELAY_LOGIN_ID in
        environmentFile (Discord bot or user login from `login` command).
      '';
    };

    relayLoginId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Optional override for bridge.relay.default_relays. If null, uses
        DISCORD_RELAY_LOGIN_ID from environmentFile (substituted by envsubst).
      '';
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
          # Pinned false: prevents any guild-space member from self-joining a portal room via
          # join_rule "restricted" (bypassing invites) — only ghosts and the bridge bot should
          # ever be room members. Matches upstream default; pinned explicitly, not just inherited.
          restricted_rooms = false;
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
          relay =
            if !bridge.relay.enable then
              {
                enabled = false;
                admin_only = false;
              }
            else
              {
                enabled = true;
                admin_only = false;
                default_relays =
                  if bridge.relayLoginId != null then
                    [ bridge.relayLoginId ]
                  else
                    [ "$DISCORD_RELAY_LOGIN_ID" ];
              };
          permissions = bridgePermissions;
        };
      };
    };

    scottylabs.postgresql.databases = [ "mautrix-discord" ];
  };
}
