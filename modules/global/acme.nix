{
  flake.modules.nixos.acme =
    { config, lib, ... }:

    let
      caddy = config.services.caddy.enable;
    in
    {
      age.secrets.cloudflare-api-token = {
        file = ../../secrets/cloudflare-api-token.age;
        mode = "0400";
      };
      sops.secrets.cloudflare-api-token = {
        sopsFile = ../../secrets/common.yaml;
        # Caddy reads it at startup, ACME renewals once per run
        restartUnits = lib.optional caddy "caddy.service";
        noRestartReason = lib.mkIf (!caddy) "only ACME renewals read it, once per run";
      };

      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "admin@scottylabs.org";
          dnsProvider = "cloudflare";
          environmentFile = config.sops.secrets.cloudflare-api-token.path;
        };
      };
    };
}
