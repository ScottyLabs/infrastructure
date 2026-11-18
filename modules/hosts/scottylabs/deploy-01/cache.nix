{ config, ... }:
let
  # Held by nixbot on infra-01
  pushKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILnL/Cshol5lq1ZPRipbGbuOAtsVEYl6N948MkpZ9My4 nixbot cache push";
  rootsKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILpFSyEUXqvjDkd8dk/ho8R4DmrMxNGVLnx6fSwAEJjG nixbot cache roots";
in
{
  flake.modules.nixos.scottylabs-deploy-01-cache =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      gcroots = "/nix/var/nix/gcroots/nixbot";

      # Replaces a project's roots with the derivations of its latest default-branch build
      roots = pkgs.writeShellApplication {
        name = "nixbot-cache-roots";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
        ];
        text = ''
          payload=$(cat)
          dir=${gcroots}/$(jq -r '.project | @uri' <<<"$payload")

          new=$(mktemp -d "$dir.XXXXXX")
          jq -r '.attributes[] | select(.drv_path != null) | [(.attr | @uri), .drv_path] | @tsv' <<<"$payload" |
            while IFS=$'\t' read -r attr drv; do
              if [ -e "$drv" ]; then
                ln -s "$drv" "$new/$attr"
              fi
            done

          rm -rf "$dir"
          mv "$new" "$dir"
        '';
      };
    in
    {
      users.users.nixbot = {
        isSystemUser = true;
        group = "nixbot";
        useDefaultShell = true;
        openssh.authorizedKeys.keys = [
          ''command="${config.nix.package}/bin/nix-daemon --stdio",restrict ${pushKey}''
          ''command="${lib.getExe roots}",restrict ${rootsKey}''
        ];
      };
      users.groups.nixbot = { };

      # nix copy --no-check-sigs needs a trusted user
      nix.settings.trusted-users = [ "nixbot" ];

      # A rooted derivation keeps its whole build closure
      nix.settings.keep-outputs = true;

      systemd.tmpfiles.rules = [ "d ${gcroots} 0755 nixbot nixbot -" ];

      # Unrooted paths stay for a week
      nix.gc.automatic = lib.mkForce false;
      services.harmonia.gc = {
        enable = true;
        automatic = true;
        keepRecent = "7d";
        deleteOlderThan = "7d";
      };

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
