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

  governancePkg = pkgs.callPackage ../../packages/governance.nix { inherit governance; };
  governanceData = "${governance}/data";

  syncScript = pkgs.writeShellScript "matrix-bridge-identity-sync" ''
    set -euo pipefail
    tmp="${stateDir}/identity-map.json.tmp"
    ${governancePkg}/bin/governance \
      --data-dir ${governanceData} \
      generate-bridge-identity-map \
      --output "$tmp"
    if [ ! -f ${mapPath} ] || ! cmp -s "$tmp" ${mapPath}; then
      mv "$tmp" ${mapPath}
      chmod 644 ${mapPath}
      echo "bridge identity map updated"
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
      Link accounts in Keycloak; cross-platform @mentions update automatically without
      committing JSON to git.
    '';

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Environment file with KEYCLOAK_CLIENT_ID and KEYCLOAK_CLIENT_SECRET for the
        governance CLI (same service account as governance CI).
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
