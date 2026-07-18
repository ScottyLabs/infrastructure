{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.matrix;
  bridge = cfg.bridges.slack;
  # ScottyLabs fork with relay, bridge identity, governance mirroring, reaction summaries on v0.2605.0
  # mautrix-go patches in thesuperRL/mautrix-go scottylabs-v0.28.0 via go.mod replace
  forkSrc = pkgs.fetchFromGitHub {
    owner = "thesuperRL";
    repo = "mautrix-slack";
    rev = "4add95891704df75489b5f400abb19986ffe4921";
    hash = "sha256-zitT5c92aLGLWCgcW+wYsACyZyKG39S0njEJituzql8=";
  };
  slackPackage = pkgs.mautrix-slack.overrideAttrs (old: {
    src = forkSrc;
    version = "26.05";
    doInstallCheck = false;
    # Build goModules from the fork's go.mod
    goModules = old.goModules.overrideAttrs {
      src = forkSrc;
      outputHash = "sha256-J1Rk6JqL4Chky59ljwJOf4GgaLU/SNyq8TSACPqbbW8=";
    };
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
  bridgePublicURL = "https://${cfg.matrixDomain}";
  # Relay display name from the per-message profile
  relayDisplayName = "{{ or .PerMessageProfile.Displayname .Displayname }}";
  # Relay templates receive .Content
  # Unlinked mentions render as [Name], Keycloak-linked users get cross-platform pings
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
      inherit (bridge) environmentFile;
      settings = {
        homeserver = {
          address = "http://127.0.0.1:${toString cfg.synapse.listenPort}";
          inherit (cfg) domain;
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
          # Relays Discord attachments from encrypted rooms
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
                  if bridge.relayLoginId != null then [ bridge.relayLoginId ] else [ "$SLACK_RELAY_LOGIN_ID" ];
                # displayname_format and icon_url show the Discord sender on Slack
                # PerMessageProfileRelay keeps Discord markdown as Slack rich text
                displayname_format = relayDisplayName;
                message_formats = {
                  "m.text" = "${relayMentionPrefix}{{ .Message }}";
                  "m.notice" = "${relayMentionPrefix}{{ .Message }}";
                  "m.emote" = "${relayMentionPrefix}* {{ .Message }}";
                  # Discord GIF embeds store the page URL in Body for Slack unfurl
                  "m.file" = "sent a file{{ if .Caption }}: {{ .Caption }}{{ end }}";
                  "m.image" = "{{ .Content.Body }}";
                  "m.audio" = "sent an audio file{{ if .Caption }}: {{ .Caption }}{{ end }}";
                  "m.video" = "{{ .Content.Body }}";
                  "m.location" = "sent a location{{ if .Caption }}: {{ .Caption }}{{ end }}";
                };
              };
          permissions = bridgePermissions;
        };
        # Encryption is configured at top level
        double_puppet = {
          secrets = {
            "${cfg.domain}" = "as_token:$DOUBLE_PUPPET_SECRET";
          };
        };
        # Encryption key comes from the environment file
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
