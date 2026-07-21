{
  flake.modules.nixos.mautrix-discord =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.matrix;
      bridge = cfg.bridges.discord;
      # ScottyLabs fork, vendored bridge v1 + mautrix-go v0.28.0
      forkSrc = pkgs.fetchFromGitHub {
        owner = "thesuperRL";
        repo = "mautrix-discord";
        rev = "38c0a91baca4ab40152fbec38e20b58a450fed16";
        hash = "sha256-nX1Vw3Pgg5myDpyvC/mEvKoPkXaV4NXxrrQfmI+b8lA=";
      };
      mautrixDiscord = pkgs.mautrix-discord.overrideAttrs (_old: {
        src = forkSrc;
        version = "0.7.6";
        doInstallCheck = false;
        vendorHash = null;
        goModules = null;
        # Deps vendored in-tree by the fork
      });
      bridgePermissions = {
        "*" = "user";
        "${cfg.domain}" = "user";
      }
      // lib.listToAttrs (
        map (uid: {
          name = uid;
          value = "admin";
        }) bridge.adminUsers
      );
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
          inherit (bridge) environmentFile;
          settings = {
            homeserver = {
              address = "http://127.0.0.1:${toString cfg.synapse.listenPort}";
              inherit (cfg) domain;
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
              # Ghost display names for relay formatting on mautrix-slack
              displayname_template = "{{if .Webhook}}Webhook{{else}}{{or .GlobalName .Username}}{{if .Bot}} (bot){{end}}{{end}}";
              double_puppet_server_map = {
                "${cfg.domain}" = "https://${cfg.matrixDomain}";
              };
              login_shared_secret_map = {
                "${cfg.domain}" = "$DOUBLE_PUPPET_SECRET";
              };
              delete_portal_on_channel_delete = true;
              # Portal rooms hold only ghosts and the bridge bot
              restricted_rooms = false;
              # Public base URL for the bridge
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
                      if bridge.relayLoginId != null then [ bridge.relayLoginId ] else [ "$DISCORD_RELAY_LOGIN_ID" ];
                  };
              permissions = bridgePermissions;
            };
          };
        };

        scottylabs.postgresql.databases = [ "mautrix-discord" ];
      };
    };
}
