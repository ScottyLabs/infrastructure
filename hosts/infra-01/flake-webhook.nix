{ config, pkgs, ... }:

let
  triggerScript = pkgs.writeShellScript "trigger-flake-update" ''
    set -euo pipefail
    
    REPO="$1"
    
    ${pkgs.curl}/bin/curl -X POST \
      -H "Authorization: token $(cat ${config.age.secrets.codeberg-token.path})" \
      -H "Content-Type: application/json" \
      "https://codeberg.org/api/v1/repos/ScottyLabs/infrastructure/actions/workflows/update-flake.yml/dispatches" \
      -d "{\"ref\": \"main\", \"inputs\": {\"input_name\": \"$REPO\"}}"
  '';
in
{
  age.secrets.codeberg-token = {
    file = ../../secrets/infra-01/codeberg-token.age;
    mode = "0400";
    owner = "webhook";
  };

  services.webhook = {
    enable = true;
    port = 9000;
    hooks = {
      flake-update = {
        execute-command = toString triggerScript;
        command-working-directory = "/tmp";
        pass-arguments-to-command = [
          { source = "payload"; name = "repository.name"; }
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

  services.nginx.virtualHosts."webhooks.scottylabs.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:9000";
    };
  };
}
