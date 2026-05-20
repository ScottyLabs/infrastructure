{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.cli-proxy-api;
  yamlFormat = pkgs.formats.yaml { };

  defaultSettings = {
    host = "127.0.0.1";
    port = cfg.port;
    auth-dir = "/var/lib/cli-proxy-api/auth";

    api-keys = [ ];

    remote-management = {
      allow-remote = false;
      disable-control-panel = true;
      secret-key = "";
    };
  };

  baseConfig = yamlFormat.generate "cli-proxy-api-base.yaml" (
    lib.recursiveUpdate defaultSettings cfg.settings
  );

  collectDeclKeys = lib.concatMapStringsSep "\n" (f: ''
    declarative=$(${pkgs.jq}/bin/jq -nc --argjson cur "$declarative" --rawfile k ${lib.escapeShellArg f} \
      '$cur + [$k | rtrimstr("\n") | rtrimstr("\r")]')
  '') cfg.apiKeyFiles;
in
{
  options.scottylabs.cli-proxy-api = {
    enable = lib.mkEnableOption "CLI Proxy API (OpenAI/Gemini/Claude/Codex-compatible multi-backend proxy)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llm-agents.cli-proxy-api;
      defaultText = lib.literalExpression "pkgs.llm-agents.cli-proxy-api";
      description = "cli-proxy-api package; provided by the numtide/llm-agents.nix overlay.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8317;
      description = "TCP port the server listens on.";
    };

    settings = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = ''
        YAML config merged on top of the module defaults (recursiveUpdate).
        See https://help.router-for.me/configuration/options for the full
        schema. The `api-keys` list and `remote-management.secret-key`
        field are overwritten at runtime from `apiKeyFiles` and
        `environmentFile` respectively — setting them here has no effect.
      '';
    };

    apiKeyFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Files (readable by the cli-proxy-api user) each containing exactly
        one API key. At startup the server's `api-keys` list is rewritten
        to the union of these declarative keys and any keys persisted in
        /var/lib/cli-proxy-api/config.yaml from the management API.
        Declarative keys come first and survive across restarts even if
        wiped from the persisted config.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file readable by the cli-proxy-api user containing:

          CLI_PROXY_MANAGEMENT_SECRET_KEY=...    (plaintext; bcrypt-hashed by the server on first start)

        This is the bearer token for the `/v0/management` API and the
        `cli-proxy-api -tui` management UI; runtime `api-keys` are added
        through that API and persisted to /var/lib/cli-proxy-api/config.yaml
        across restarts. Typically wired to an agenix secret.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.cli-proxy-api = {
      isSystemUser = true;
      group = "cli-proxy-api";
      home = "/var/lib/cli-proxy-api";
    };
    users.groups.cli-proxy-api = { };

    systemd.services.cli-proxy-api = {
      description = "CLI Proxy API";
      after = [ "network-online.target" ] ++ lib.optional (cfg.apiKeyFiles != [ ]) "bao-agent.service";
      wants = [ "network-online.target" ] ++ lib.optional (cfg.apiKeyFiles != [ ]) "bao-agent.service";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "cli-proxy-api";
        Group = "cli-proxy-api";
        StateDirectory = "cli-proxy-api";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/cli-proxy-api";
        EnvironmentFile = cfg.environmentFile;

        ExecStartPre = pkgs.writeShellScript "cli-proxy-api-render-config" ''
          set -euo pipefail
          umask 077
          : "''${CLI_PROXY_MANAGEMENT_SECRET_KEY:?CLI_PROXY_MANAGEMENT_SECRET_KEY must be set in environmentFile}"
          CONFIG=/var/lib/cli-proxy-api/config.yaml

          declarative='[]'
          ${collectDeclKeys}

          if [ -f "$CONFIG" ]; then
            existing=$(${pkgs.yq-go}/bin/yq -o=json '.api-keys // []' "$CONFIG")
          else
            existing='[]'
          fi
          combined=$(${pkgs.jq}/bin/jq -nc --argjson a "$declarative" --argjson b "$existing" '$a + ($b - $a)')

          COMBINED="$combined" ${pkgs.yq-go}/bin/yq eval \
            '.api-keys = (strenv(COMBINED) | from_json)
             | .remote-management.secret-key = strenv(CLI_PROXY_MANAGEMENT_SECRET_KEY)' \
            ${baseConfig} > "$CONFIG.new"
          ${pkgs.coreutils}/bin/mv "$CONFIG.new" "$CONFIG"
          ${pkgs.coreutils}/bin/mkdir -p /var/lib/cli-proxy-api/auth
        '';

        ExecStart = "${lib.getExe cfg.package} -config /var/lib/cli-proxy-api/config.yaml";
        Restart = "on-failure";
        RestartSec = 5;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        ReadWritePaths = [ "/var/lib/cli-proxy-api" ];
      };
    };
  };
}
