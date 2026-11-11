{ inputs, ... }:
let
  vendor = inputs.infrastructure-vendor.falcon-sensor;
in
{
  flake.modules.nixos.falcon-sensor =
    { config, ... }:

    {
      imports = [ inputs.falcon-sensor.nixosModules.default ];

      nixpkgs.config.allowUnfreePackages = [ "falcon-sensor" ];

      age.secrets.falcon-sensor.file = ../../secrets/falcon-sensor.age;

      services.falcon-sensor = {
        enable = true;
        inherit (vendor) srcs;
        environmentFile = config.age.secrets.falcon-sensor.path;
      };
    };

  flake.modules.darwin.falcon-sensor =
    { config, ... }:

    {
      imports = [ inputs.falcon-sensor.darwinModules.default ];

      age.secrets.falcon-sensor.file = ../../secrets/falcon-sensor.age;

      services.falcon-sensor = {
        enable = true;
        src = vendor.darwin;
        environmentFile = config.age.secrets.falcon-sensor.path;
      };
    };
}
