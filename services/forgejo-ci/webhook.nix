{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.forgejoCI.webhook;

  triggerScript = pkgs.writeShellScript "trigger-flake-update" ''
    set -euo pipefail

    REPO="$1"

    ${pkgs.curl}/bin/curl -X POST \
      -H "Authorization: token $(cat ${cfg.tokenFile})" \
      -H "Content-Type: application/json" \
      "${cfg.apiBase}/repos/${cfg.targetRepo}/actions/workflows/${cfg.workflow}/dispatches" \
      -d "{\"ref\": \"main\", \"inputs\": {\"input_name\": \"$REPO\"}}"
  '';
in
{
  options.scottylabs.forgejoCI.webhook = {
    enable = lib.mkEnableOption "Webhook receiver that dispatches a Forgejo Actions workflow on push";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "webhooks.scottylabs.org";
      description = "Public hostname caddy reverse-proxies to the webhook listener.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file containing a Forgejo API token with workflow dispatch permission.";
    };

    apiBase = lib.mkOption {
      type = lib.types.str;
      default = "https://codeberg.org/api/v1";
      description = "Forgejo API base URL.";
    };

    targetRepo = lib.mkOption {
      type = lib.types.str;
      default = "ScottyLabs/infrastructure";
      description = "owner/repo of the Forgejo repository whose workflow will be dispatched.";
    };

    workflow = lib.mkOption {
      type = lib.types.str;
      default = "update-flake.yml";
      description = "Workflow file name to dispatch.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.webhook = {
      enable = true;
      port = cfg.port;
      hooks = {
        flake-update = {
          execute-command = toString triggerScript;
          command-working-directory = "/tmp";
          pass-arguments-to-command = [
            {
              source = "payload";
              name = "repository.name";
            }
          ];
          trigger-rule = {
            or = [
              {
                match = {
                  type = "value";
                  value = "push";
                  parameter = {
                    source = "header";
                    name = "X-GitHub-Event";
                  };
                };
              }
              {
                match = {
                  type = "value";
                  value = "push";
                  parameter = {
                    source = "header";
                    name = "X-Forgejo-Event";
                  };
                };
              }
              {
                match = {
                  type = "value";
                  value = "push";
                  parameter = {
                    source = "header";
                    name = "X-Gitea-Event";
                  };
                };
              }
            ];
          };
        };
      };
    };

    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      reverse_proxy 127.0.0.1:${toString cfg.port}
    '';
  };
}
