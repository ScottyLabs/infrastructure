{ config, ... }:
{
  flake.modules.nixos.scottylabs-deploy-01-cache =
    { config, ... }:

    {
      services.caddy.virtualHosts."cache.scottylabs.org".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString config.scottylabs.harmonia.port}
      '';
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.cache = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/cache.tfstate";
            dns.cache = {
              name = "cache";
              tunnel = "scottylabs-deploy-01";
              comment = "Public binary cache served by harmonia on deploy-01";
            };
          }
        ];
      };
    };
}
