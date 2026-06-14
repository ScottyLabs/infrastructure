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
  slackPackage = pkgs.mautrix-slack.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../patches/mautrix-slack-relay-outbound.patch
      ../../patches/mautrix-slack-preserve-topic.patch
      ../../patches/mautrix-slack-bridge-identity-pings.patch
      ../../patches/mautrix-slack-bridge-identity-relay-mentions.patch
      ../../patches/mautrix-slack-bridge-identity-dedupe.patch
      ../../patches/mautrix-slack-skip-thread-creation-relay.patch
      ../../patches/mautrix-slack-room-ping.patch
      ../../patches/mautrix-bridge-identity-matrix-mxid.patch
      ../../patches/mautrix-bridge-identity-keycloak.patch
      ../../patches/mautrix-bridge-identity-slack-ghost-parse.patch
      ../../patches/mautrix-bridge-identity-keycloak-hotpath.patch
      ../../patches/mautrix-slack-reaction-mirror-summary.patch
    ];
    postConfigure = (old.postConfigure or "") + ''
      mautrix_dir="vendor/maunium.net/go/mautrix"
      if [ ! -d "$mautrix_dir" ]; then
        mautrix_dir="$(go list -m -f '{{.Dir}}' maunium.net/go/mautrix)"
      fi
      chmod -R u+w "$mautrix_dir"
      patch -p1 -d "$mautrix_dir" < ${../../patches/mautrix-bridgev2-relay-reactions.patch}
      patch -p1 -d "$mautrix_dir" < ${../../patches/mautrix-bridgev2-reaction-mirror-hook.patch}
    '';
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
  bridgePublicURL = "https://${cfg.matrixDomain}";
  # Discord puppets attach com.beeper.per_message_profile (GlobalName/username). Do not use
  # DisambiguatedName — it becomes "Name via other (@discord_…:domain)" when names collide.
  # message_formats use .Sender.*; displayname_format uses the same fields without that prefix.
  relayDisplayName = "{{ or .PerMessageProfile.Displayname .Displayname }}";
  # Relay templates also receive .Content (see mautrix-go bridgeconfig formatData).
  # Unlinked mentions become [Name] labels; Keycloak-linked users get real cross-platform pings (synced from Keycloak).
  relayMentionPrefix = "";
in
{
  imports = [ ./nixos-mautrix-slack.nix ];

  options.scottylabs.matrix.bridges.slack = {
    enable = lib.mkEnableOption "mautrix-slack bridge";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to env file containing DOUBLE_PUPPET_SECRET, ENCRYPTION_PICKLE_KEY,
        PUBLIC_MEDIA_SIGNING_KEY, and SLACK_RELAY_LOGIN_ID (see
        secrets/infra-01/double-puppet-env.example).
      '';
    };

    adminUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Matrix user IDs granted bridge admin permissions.";
    };

    relay.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable mautrix-slack relay so Discord puppets (and other users without Slack login)
        reach Slack via the relay login. Requires SLACK_RELAY_LOGIN_ID in environmentFile
        (must be a Slack **app** login from `login app`, not `login token`).
      '';
    };

    relayLoginId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Optional override for bridge.relay.default_relays. If null, uses
        SLACK_RELAY_LOGIN_ID from environmentFile (substituted by envsubst).
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
          # Required for relaying Discord attachments from encrypted rooms (content.file, not url).
          use_database = true;
        };
        bridge = {
          custom_emoji_reactions = true;
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
                prefer_default = true;
                default_relays =
                  if bridge.relayLoginId != null then
                    [ bridge.relayLoginId ]
                  else
                    [ "$SLACK_RELAY_LOGIN_ID" ];
                # displayname_format + icon_url (needs public_media) show Discord sender on Slack.
                # PerMessageProfileRelay (patched in mautrix-slack) skips relay message_formats for
                # text so Discord markdown survives as Slack rich text; formats below still apply to
                # media fallbacks and non-relay paths.
                displayname_format = relayDisplayName;
                # Keys must be quoted — unquoted m.text becomes nested YAML { m: { text: ... } }.
                message_formats = {
                  "m.text" = "${relayMentionPrefix}{{ .Message }}";
                  "m.notice" = "${relayMentionPrefix}{{ .Message }}";
                  "m.emote" = "${relayMentionPrefix}* {{ .Message }}";
                  # Discord GIF embeds (Tenor, etc.) store the page URL in Body; keep it for Slack unfurl.
                  "m.file" = "sent a file{{ if .Caption }}: {{ .Caption }}{{ end }}";
                  "m.image" = "{{ .Content.Body }}";
                  "m.audio" = "sent an audio file{{ if .Caption }}: {{ .Caption }}{{ end }}";
                  "m.video" = "{{ .Content.Body }}";
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
