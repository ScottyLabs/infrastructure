{ config, ... }:
{
  flake.modules.nixos.deploy-01-ricochet =
    { inputs, ... }:

    {
      imports = [
        inputs.ricochet.nixosModules.default
      ];

      services.ricochet = {
        enable = true;
        package = inputs.ricochet.packages.x86_64-linux.ricochet;
        bind = "127.0.0.1:8090";
        allowedHosts = [ "*.scottylabs.net" ];
        # Kennel-published custom domains allowed as return_to targets
        allowedHostsFile = "/run/kennel/custom-domains";
      };

      services.caddy.virtualHosts."oauth.scottylabs.org".extraConfig = ''
        reverse_proxy 127.0.0.1:8090
      '';
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.ricochet = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          {
            terraform.backend.s3.key = "services/ricochet.tfstate";
            dns.oauth = {
              host = "deploy-01";
              type = "CNAME";
              comment = "Ricochet OAuth callback relay";
            };
          }
        ];
      };
    };
}
