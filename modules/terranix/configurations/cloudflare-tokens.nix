{
  config,
  inputs,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.cloudflare-tokens = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/cloudflare-tokens.tfstate";

            # Manual token with only User API Tokens Edit
            cloudflare.token = null;
            variable.cloudflare_tokens_api_token.sensitive = true;
            provider.cloudflare.api_token = "\${var.cloudflare_tokens_api_token}";

            cloudflare.tokens = {
              caddy = {
                zonePermissions = [
                  "Zone Read"
                  "DNS Write"
                ];
                hosts = lib.attrNames (
                  lib.filterAttrs (_: host: host.config.services.caddy.enable) inputs.self.nixosConfigurations
                );
              };

              terranix-dns.zonePermissions = [
                "Zone Read"
                "DNS Write"
              ];

              terranix-hosts = {
                accountPermissions = [ "Cloudflare Tunnel Write" ];
                zonePermissions = [
                  "Zone Read"
                  "DNS Write"
                  "Zone Settings Write"
                ];
              };

              terranix-mail = {
                accountPermissions = [ "Email Sending Write" ];
                zonePermissions = [
                  "Zone Read"
                  "DNS Write"
                ];
                zones = [
                  "cmu.dev"
                  "scottylabs.org"
                  "scottylabs.dev"
                ];
              };

              smtp.accountPermissions = [ "Email Sending Write" ];

              kennel = {
                zonePermissions = [
                  "Zone Read"
                  "DNS Write"
                ];
                hosts = [ "scottylabs-deploy-01" ];
              };
            };
          }
        ];
      };
    };
}
