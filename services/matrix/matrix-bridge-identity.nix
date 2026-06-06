# Sync Discord ↔ Slack identity links from Keycloak for cross-platform @mentions on mautrix bridges.
{
  config,
  lib,
  pkgs,
  governance,
  ...
}:

let
  cfg = config.scottylabs.matrix;
  syncCfg = cfg.bridgeIdentitySync;

  stateDir = "/var/lib/mautrix-bridge";
  mapPath = "${stateDir}/identity-map.json";

  org = builtins.fromTOML (builtins.readFile "${governance}/data/org.toml");
  keycloakUrl = org.org.keycloak.url;
  keycloakRealm = org.org.keycloak.realm;
  slackTeamId = org.org.communication.slack_team_id;

  syncScript = pkgs.writeShellScript "matrix-bridge-identity-sync" ''
    set -euo pipefail

    : "''${KEYCLOAK_CLIENT_ID:?KEYCLOAK_CLIENT_ID not set}"
    : "''${KEYCLOAK_CLIENT_SECRET:?KEYCLOAK_CLIENT_SECRET not set}"

    tmp="${stateDir}/identity-map.json.tmp"
    keycloak_url=${lib.escapeShellArg keycloakUrl}
    keycloak_realm=${lib.escapeShellArg keycloakRealm}
    slack_team_id=${lib.escapeShellArg slackTeamId}

    token=$(${pkgs.curlMinimal}/bin/curl -sf -X POST "''${keycloak_url}/realms/''${keycloak_realm}/protocol/openid-connect/token" \
      --data-urlencode "grant_type=client_credentials" \
      --data-urlencode "client_id=''${KEYCLOAK_CLIENT_ID}" \
      --data-urlencode "client_secret=''${KEYCLOAK_CLIENT_SECRET}" \
      | ${pkgs.jq}/bin/jq -r .access_token)

    if [ -z "$token" ] || [ "$token" = "null" ]; then
      echo "failed to obtain keycloak access token" >&2
      exit 1
    fi

    links_json='[]'
    first=0
    max=100
    while true; do
      users=$(${pkgs.curlMinimal}/bin/curl -sf \
        -H "Authorization: Bearer ''${token}" \
        "''${keycloak_url}/admin/realms/''${keycloak_realm}/users?first=''${first}&max=''${max}")
      count=$(echo "$users" | ${pkgs.jq}/bin/jq 'length')
      if [ "$count" -eq 0 ]; then
        break
      fi

      while IFS= read -r user_id; do
        [ -z "$user_id" ] && continue
        fed=$(${pkgs.curlMinimal}/bin/curl -sf \
          -H "Authorization: Bearer ''${token}" \
          "''${keycloak_url}/admin/realms/''${keycloak_realm}/users/''${user_id}/federated-identity" 2>/dev/null || echo '[]')
        discord_id=$(echo "$fed" | ${pkgs.jq}/bin/jq -r '[.[] | select(.identityProvider == "discord") | (.userId // .userName)] | first // empty')
        slack_id=$(echo "$fed" | ${pkgs.jq}/bin/jq -r '[.[] | select(.identityProvider == "slack") | (.userId // .userName)] | first // empty')
        if [ -n "$discord_id" ] && [ -n "$slack_id" ]; then
          links_json=$(echo "$links_json" | ${pkgs.jq}/bin/jq --arg d "$discord_id" --arg s "$slack_id" '. + [{discord_id: $d, slack_user_id: $s}]')
        fi
      done < <(echo "$users" | ${pkgs.jq}/bin/jq -r '.[].id')

      if [ "$count" -lt "$max" ]; then
        break
      fi
      first=$((first + max))
    done

    ${pkgs.jq}/bin/jq -n --arg team "$slack_team_id" --argjson links "$links_json" \
      '{slack_team_id: $team, links: ($links | sort_by(.discord_id))}' > "$tmp"

    if [ ! -f ${mapPath} ] || ! cmp -s "$tmp" ${mapPath}; then
      mv "$tmp" ${mapPath}
      chmod 644 ${mapPath}
      link_count=$(echo "$links_json" | ${pkgs.jq}/bin/jq 'length')
      echo "bridge identity map updated (''${link_count} links)"
      systemctl try-restart mautrix-discord.service mautrix-slack.service || true
    else
      rm -f "$tmp"
      echo "bridge identity map unchanged"
    fi
  '';
in
{
  options.scottylabs.matrix.bridgeIdentitySync = {
    enable = lib.mkEnableOption ''
      Periodically sync Discord/Slack IdP links from Keycloak into a runtime identity map.
      Any Keycloak user with both Discord and Slack linked is included automatically.
    '';

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Environment file with KEYCLOAK_CLIENT_ID and KEYCLOAK_CLIENT_SECRET (governance CI service account).
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "How often to refresh the identity map from Keycloak.";
    };
  };

  config = lib.mkIf (cfg.enable && syncCfg.enable) {
    assertions = [
      {
        assertion = syncCfg.environmentFile != null;
        message = "scottylabs.matrix.bridgeIdentitySync.environmentFile must be set when sync is enabled.";
      }
      {
        assertion = org.org.keycloak ? url && org.org.keycloak ? realm;
        message = "governance org.toml must define org.keycloak.url and org.keycloak.realm.";
      }
      {
        assertion = org.org.communication ? slack_team_id;
        message = "governance org.toml must define org.communication.slack_team_id.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
    ];

    systemd.services.matrix-bridge-identity-sync = {
      description = "Sync mautrix bridge identity map from Keycloak";
      after = [
        "network-online.target"
        "keycloak.service"
      ];
      wants = [
        "network-online.target"
        "keycloak.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = syncCfg.environmentFile;
        ExecStart = syncScript;
      };
    };

    systemd.timers.matrix-bridge-identity-sync = {
      description = "Refresh mautrix bridge identity map from Keycloak";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = syncCfg.interval;
        Unit = "matrix-bridge-identity-sync.service";
      };
    };

    systemd.services.mautrix-slack.serviceConfig.Environment = lib.mkAfter [
      "BRIDGE_IDENTITY_MAP_PATH=${mapPath}"
    ];

    systemd.services.mautrix-discord.serviceConfig.Environment = lib.mkAfter [
      "BRIDGE_IDENTITY_MAP_PATH=${mapPath}"
    ];
  };
}
