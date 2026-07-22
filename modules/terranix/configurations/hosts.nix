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
      terranix.terranixConfigurations.hosts = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/hosts.tfstate";
            dns = lib.mapAttrs (name: host: {
              target = host.config.scottylabs.publicIp;
              type = "A";
              comment = "NixOS host ${name}";
            }) inputs.self.nixosConfigurations;
          }
        ];
      };
    };
}
