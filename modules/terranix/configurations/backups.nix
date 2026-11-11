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
      terranix.terranixConfigurations.backups = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/backups.tfstate";
            cloudflare.token = "terranix-backups";

            resource.cloudflare_r2_bucket =
              lib.mapAttrs
                (_: host: {
                  account_id = import ../../../data/cloudflare-account.nix;
                  name = host.config.scottylabs.backup.bucket;
                })
                (lib.filterAttrs (_: host: host.config.scottylabs.backup.enable) inputs.self.nixosConfigurations);
          }
        ];
      };
    };
}
