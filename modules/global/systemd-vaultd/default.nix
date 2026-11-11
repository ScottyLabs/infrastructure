{ inputs, ... }:
{
  flake.modules.nixos.systemd-vaultd =
    {
      config,
      lib,
      options,
      ...
    }:

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
        assertions = lib.mapAttrsToList (name: service: {
          assertion =
            service.vault.environmentTemplate == null
            # systemd requests credentials from abstract socket @<16 random hex>/unit/<unit>/<credential>
            # Past 107 bytes this fails with "No such device or address"
            ||
              lib.stringLength "@0123456789abcdef/unit/${name}-envfile.service/${name}.service.EnvironmentFile"
              <= 107;
          message = "systemd.services.${name}: vault.environmentTemplate needs a service name of at most 21 characters";
        }) config.systemd.services;

        # TODO: replace systemd-vaultd
        services.systemd-vaultd.package =
          options.services.systemd-vaultd.package.default.overrideAttrs
            (old: {
              patches = (old.patches or [ ]) ++ [ ./wait-for-missing-keys.patch ];
            });

        age.secrets.bao-role-id = {
          file = ../../../secrets/${config.scottylabs.organization}/${config.networking.hostName}/bao-role-id.age;
          mode = "0400";
        };
        age.secrets.bao-secret-id = {
          file = ../../../secrets/${config.scottylabs.organization}/${config.networking.hostName}/bao-secret-id.age;
          mode = "0400";
        };

        services.vault.agents.default.settings = {
          vault.address =
            if config.services.openbao.enable then
              "http://127.0.0.1:8200"
            else
              "https://secrets.scottylabs.org";
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
