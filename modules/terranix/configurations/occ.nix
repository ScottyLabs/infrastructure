{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.occ = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/occ.tfstate";

            dns.incus = {
              zone = "occ.build";
              target = "128.2.96.10";
              type = "A";
              comment = "OCC Incus API on mimosa";
            };
          }
        ];
      };
    };
}
