{ inputs, lib, ... }:
let
  # macOS's AirPlay Receiver holds 5000
  port = 5001;
  keys = import ../../data/hosts.nix;

  harmonia =
    { config, ... }:

    {
      options.scottylabs.harmonia.port = lib.mkOption {
        type = lib.types.port;
        default = port;
        readOnly = true;
        description = "Port harmonia serves this host's store on";
      };

      config = {
        age.secrets.harmonia-signing-key.file =
          ../../secrets
          + "/${config.scottylabs.organization}/${config.networking.hostName}/harmonia-signing-key.age";

        services.harmonia.cache = {
          enable = true;
          signKeyPaths = [ config.age.secrets.harmonia-signing-key.path ];
          settings.bind = "[::]:${toString port}";
        };

        services.ncro.settings.upstreams =
          lib.mapAttrsToList
            (_: host: {
              url = "http://${host.config.networking.hostName}.tail.scottylabs.org:${toString port}";
              # Ahead of the public caches when latencies tie
              priority = 5;
              public_key = keys.${host.config.scottylabs.organization}.${host.config.networking.hostName}.cache;
            })
            (
              lib.removeAttrs (inputs.self.nixosConfigurations // inputs.self.darwinConfigurations) [
                "${config.scottylabs.organization}-${config.networking.hostName}"
              ]
            );
      };
    };
in
{
  flake.modules.nixos.harmonia = harmonia;

  flake.modules.darwin.harmonia = {
    imports = [ harmonia ];

    age.secrets.harmonia-signing-key.owner = "_harmonia";
  };
}
