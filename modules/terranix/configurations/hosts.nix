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
            dns =
              (lib.mapAttrs (name: host: {
                target = host.config.scottylabs.ipAddress;
                type = "A";
                comment = "NixOS host ${name}";
              }) inputs.self.nixosConfigurations)
              // (lib.mapAttrs (name: host: {
                target = host.config.scottylabs.ipAddress;
                type = "A";
                comment = "darwin host ${name}";
              }) inputs.self.darwinConfigurations);

            resource.cloudflare_zone_setting.always_use_https = {
              for_each = "\${{ for z in data.cloudflare_zones.all.result : z.id => z.id }}";
              zone_id = "\${each.value}";
              setting_id = "always_use_https";
              value = "on";
            };
          }
        ];
      };
    };
}
