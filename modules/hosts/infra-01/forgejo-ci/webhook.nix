{ config, ... }:
{
  flake.modules.nixos.webhook =
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

      pushEventTriggerRule = {
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

      triggerRenovateScript = pkgs.writeShellScript "trigger-renovate" ''
        set -euo pipefail
        ${pkgs.sudo}/bin/sudo ${pkgs.systemd}/bin/systemctl start renovate.service
      '';

      mainBranchTriggerRule = {
        and = [
          pushEventTriggerRule
          {
            match = {
              type = "value";
              value = "refs/heads/main";
              parameter = {
                source = "payload";
                name = "ref";
              };
            };
          }
        ];
      };

      triggerDocsDiagramsScript = pkgs.writeShellApplication {
        name = "trigger-docs-diagrams";
        runtimeInputs = with pkgs; [
          bash
          jq
          curl
        ];
        text = ''
          export FORGEJO_TOKEN_FILE=${cfg.tokenFile}
          export FORGEJO_API_BASE=${cfg.apiBase}
          export DOCS_TARGET_REPO=${cfg.docsTargetRepo}
          exec ${pkgs.bash}/bin/bash ${./trigger-docs-diagrams.sh}
        '';
      };
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

        docsTargetRepo = lib.mkOption {
          type = lib.types.str;
          default = "ScottyLabs/documentation";
          description = "owner/repo dispatched when docs/ or diagram files change in a push.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.webhook = {
          enable = true;
          inherit (cfg) port;
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
              trigger-rule = pushEventTriggerRule;
            };
            docs-diagrams = {
              execute-command = lib.getExe triggerDocsDiagramsScript;
              command-working-directory = "/tmp";
              trigger-rule = pushEventTriggerRule;
            };
            renovate-update = {
              execute-command = toString triggerRenovateScript;
              command-working-directory = "/tmp";
              trigger-rule = mainBranchTriggerRule;
            };
          };
        };

        security.sudo.extraRules = [
          {
            users = [ "webhook" ];
            commands = [
              {
                command = "${pkgs.systemd}/bin/systemctl start renovate.service";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];

        services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
          reverse_proxy 127.0.0.1:${toString cfg.port}
        '';
      };
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.webhook = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          {
            terraform.backend.s3.key = "services/webhook.tfstate";
            dns.webhooks = {
              host = "infra-01";
              type = "CNAME";
              comment = "Nix flake updates for infrastructure";
            };
          }
        ];
      };
    };
}
