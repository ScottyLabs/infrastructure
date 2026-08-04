{ config, ... }:
{
  flake.modules.nixos.infra-01-webhook =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.forgejoCI.webhook;

      pushEventTriggerRule = {
        "or" = [
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

    in
    {
      options.scottylabs.forgejoCI.webhook = {
        domain = lib.mkOption {
          type = lib.types.str;
          default = "webhooks.scottylabs.org";
          description = "Public hostname caddy reverse-proxies to the webhook listener.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 9000;
        };
      };

      config = {
        services.webhook = {
          enable = true;
          inherit (cfg) port;
          hooks = {
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
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/webhook.tfstate";
            dns.webhooks = {
              tunnel = "infra-01";
              comment = "Renovate trigger webhook receiver";
            };
          }
        ];
      };
    };
}
