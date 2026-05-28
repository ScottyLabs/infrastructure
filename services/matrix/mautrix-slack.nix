{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.matrix;
  bridge = cfg.bridges.slack;
  # synapse_mautrix_slack_link and manual plumbing need `!slack bridge` (added in v26.04).
  slackPackage = pkgs.mautrix-slack;
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

    relayLoginId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "T03EVH29W-U0A7HGVMPB6";
      description = ''
        mautrix-slack login ID for ops+slack (from `list-logins` in the @slack management room).
        When set, relay mode is enabled so Discord-originated messages in plumbed portal rooms
        reach Slack without each user running `login token`.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && bridge.enable) {
    assertions = [
      {
        assertion = lib.versionAtLeast slackPackage.version "26.04";
        message = "mautrix-slack >= 26.04 is required for !slack bridge (plumbing into Discord portals). Update nixpkgs (nix flake update nixpkgs).";
      }
    ];

    services.mautrix-slack = {
      enable = true;
      package = slackPackage;
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
          relay =
            if bridge.relayLoginId == null then
              {
                enabled = false;
                admin_only = false;
              }
            else
              {
                enabled = true;
                admin_only = false;
                prefer_default = true;
                default_relays = [ bridge.relayLoginId ];
                # Per-message display names on Slack (Discord puppet names, etc.).
                # Keys must be quoted — unquoted m.text becomes nested YAML { m: { text: ... } }.
                message_formats = {
                  "m.text" = "{{ .Message }}";
                  "m.notice" = "{{ .Message }}";
                  "m.emote" = "{{ .Message }}";
                  "m.file" = "{{ .Message }}";
                  "m.image" = "{{ .Message }}";
                  "m.audio" = "{{ .Message }}";
                  "m.video" = "{{ .Message }}";
                  "m.location" = "{{ .Message }}";
                };
                displayname_format = "{{ .DisambiguatedName }}";
              };
          permissions = bridgePermissions;
        };
        # mautrix-slack v25+ uses top-level encryption (bridge.encryption is ignored).
        double_puppet = {
          secrets = {
            "${cfg.domain}" = "as_token:$DOUBLE_PUPPET_SECRET";
          };
        };
        # Stable key via environmentFile — "generate" in Nix settings is rewritten on
        # every deploy and breaks the bridge DB (invalid pickle key / E2EE failures).
        encryption = {
          allow = true;
          default = true;
          allow_key_sharing = true;
          pickle_key = "$ENCRYPTION_PICKLE_KEY";
          self_sign = true;
        };
      };
    };

    scottylabs.postgresql.databases = [ "mautrix-slack" ];
  };
}
