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
            cloudflare.token = "terranix-hosts";
            dns =
              let
                zones = import ../../../zones.nix;
                record = kind: id: host: {
                  name = host.config.networking.hostName;
                  zone = host.config.scottylabs.domain;
                  target = host.config.scottylabs.ipAddress;
                  type = "A";
                  comment = "${kind} host ${id}";
                };
              in
              lib.filterAttrs (_: e: zones ? ${e.zone}) (
                lib.mapAttrs (record "NixOS") inputs.self.nixosConfigurations
                // lib.mapAttrs (record "darwin") inputs.self.darwinConfigurations
              );

            resource.cloudflare_zone_setting.always_use_https = {
              for_each = lib.mapAttrs' (_: id: lib.nameValuePair id id) (import ../../../zones.nix);
              zone_id = "\${each.value}";
              setting_id = "always_use_https";
              value = "on";
            };
          }
        ];
      };
    };
}
