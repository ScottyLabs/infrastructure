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
  bridgePublicURL = "https://${cfg.matrixDomain}";
  # Discord puppets attach com.beeper.per_message_profile (GlobalName/username). Do not use
  # DisambiguatedName — it becomes "Name via other (@discord_…:domain)" when names collide.
  # message_formats use .Sender.*; displayname_format uses the same fields without that prefix.
  relayDisplayName = "{{ or .PerMessageProfile.Displayname .Displayname }}";
  # Relay templates also receive .Content (see mautrix-go bridgeconfig formatData). Prefix when
  # Matrix m.mentions is set (@user / @room from Discord pings).
  relayMentionPrefix = "{{ with .Content.Mentions }}{{ if or .Room .UserIDs }}[ping] {{ end }}{{ end }}";
in
{
  imports = [ ./nixos-mautrix-slack.nix ];

  options.scottylabs.matrix.bridges.slack = {
    enable = lib.mkEnableOption "mautrix-slack bridge";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to env file containing DOUBLE_PUPPET_SECRET, ENCRYPTION_PICKLE_KEY, and
        PUBLIC_MEDIA_SIGNING_KEY (for relay avatar URLs on Slack).
      '';
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
          hostname = "127.0.0.1";
          port = 29335;
          public_address = bridgePublicURL;
          bot = {
            username = "slack";
            displayname = "Slack Bridge";
          };
        };
        public_media = {
          enabled = true;
          signing_key = "$PUBLIC_MEDIA_SIGNING_KEY";
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
                # displayname_format + icon_url (needs public_media) show Discord sender on Slack;
                # message body only carries text and optional [ping] prefix.
                displayname_format = relayDisplayName;
                # Keys must be quoted — unquoted m.text becomes nested YAML { m: { text: ... } }.
                message_formats = {
                  "m.text" = "${relayMentionPrefix}{{ .Message }}";
                  "m.notice" = "${relayMentionPrefix}{{ .Message }}";
                  "m.emote" = "${relayMentionPrefix}* {{ .Message }}";
                  "m.file" = "sent a file{{ if .Caption }}: {{ .Caption }}{{ end }}";
                  "m.image" = "sent an image{{ if .Caption }}: {{ .Caption }}{{ end }}";
                  "m.audio" = "sent an audio file{{ if .Caption }}: {{ .Caption }}{{ end }}";
                  "m.video" = "sent a video{{ if .Caption }}: {{ .Caption }}{{ end }}";
                  "m.location" = "sent a location{{ if .Caption }}: {{ .Caption }}{{ end }}";
                };
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
