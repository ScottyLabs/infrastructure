{ config, internet-archive, ... }:

{
  imports = [
    internet-archive.nixosModules.default
  ];

  age.secrets.internet-archive = {
    file = ../../secrets/prod-01/internet-archive.age;
    mode = "0400";
    owner = "internet-archive";
  };

  services.internet-archive = {
    enable = true;
    environmentFile = config.age.secrets.internet-archive.path;
    presets = [ "soc" ];
    schedule = "weekly";
    debug = true;
  };
}
