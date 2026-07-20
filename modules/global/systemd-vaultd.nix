{ inputs, ... }:
{
  flake.modules.nixos.systemd-vaultd =
    {
      config,
      lib,
      ...
    }:

    let
      # TODO: https://github.com/numtide/systemd-vaultd/pull/65
      baoShimOverlay = _final: prev: {
        vault = prev.writeShellScriptBin "vault" ''exec ${prev.openbao}/bin/bao "$@"'';
      };
    in
    {
      imports = [
        inputs.systemd-vaultd.nixosModules.vaultAgent
        inputs.systemd-vaultd.nixosModules.systemdVaultd
      ];

      options.systemd.services = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { config, ... }:
            {
              options.vault.infraSecrets = lib.mkOption {
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options.path = lib.mkOption { type = lib.types.str; };
                    options.key = lib.mkOption { type = lib.types.str; };
                  }
                );
                default = { };
                description = "OpenBao infra secrets exposed as credentials, keyed by credential name";
              };

              config.vault = lib.mkIf (config.vault.infraSecrets != { }) {
                template = lib.concatStringsSep "\n" (
                  (lib.mapAttrsToList (
                    cred: s:
                    ''{{ with secret "secret/data/infra/${s.path}" }}{{ scratch.MapSet "s" "${cred}" .Data.data.${s.key} }}{{ end }}''
                  ) config.vault.infraSecrets)
                  ++ [ ''{{ scratch.Get "s" | explodeMap | toJSON }}'' ]
                );
                secrets = lib.mapAttrs (_: _: { }) config.vault.infraSecrets;
              };
            }
          )
        );
      };

      config = {
        nixpkgs.overlays = [ baoShimOverlay ];

        age.secrets.bao-role-id = {
          file = ../../secrets/${config.networking.hostName}/bao-role-id.age;
          mode = "0400";
        };
        age.secrets.bao-secret-id = {
          file = ../../secrets/${config.networking.hostName}/bao-secret-id.age;
          mode = "0400";
        };

        services.vault.agents.default.settings = {
          vault.address = "https://secrets.scottylabs.org";
          auto_auth.method = [
            {
              type = "approle";
              config = {
                role_id_file_path = "/run/agenix/bao-role-id";
                secret_id_file_path = "/run/agenix/bao-secret-id";
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
      };
    };
}
