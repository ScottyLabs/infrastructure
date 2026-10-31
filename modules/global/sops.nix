let
  # Lets a secret that needs no restart say so, which silences the warning below
  noRestartReason =
    { lib, ... }:
    {
      options.sops.secrets = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.noRestartReason = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Why no unit has to restart when this secret changes, such as it being read on each use";
            };
          }
        );
      };
    };
in
{
  flake.modules.nixos.sops =
    { config, lib, ... }:

    {
      imports = [ noRestartReason ];

      # Readable by this host and the admins, see the rules in devenv.nix
      sops.defaultSopsFile = ../../secrets/${config.scottylabs.organization}/${config.networking.hostName}.yaml;

      # sops-nix runs systemctl try-restart on these, which skips a misspelled unit without a word
      assertions = lib.mapAttrsToList (
        name: secret:
        let
          missing = lib.filter (unit: !config.systemd.units ? ${unit}) (
            secret.restartUnits ++ secret.reloadUnits
          );
        in
        {
          assertion = missing == [ ];
          message = "sops.secrets.${name} restarts or reloads ${lib.concatStringsSep ", " missing}, which this host does not define";
        }
      ) config.sops.secrets;

      warnings = lib.concatLists (
        lib.mapAttrsToList (
          name: secret:
          lib.optional (
            secret.restartUnits == [ ] && secret.reloadUnits == [ ] && secret.noRestartReason == null
          ) "sops.secrets.${name} restarts nothing when it changes, set restartUnits or noRestartReason"
        ) config.sops.secrets
      );
    };

  flake.modules.darwin.sops = noRestartReason;
}
