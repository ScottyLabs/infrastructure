{ config, dalmatian, ... }:

{
  imports = [
    dalmatian.nixosModules.default
  ];

  age.secrets.dalmatian = {
    file = ../../secrets/prod-01/dalmatian.age;
    mode = "0400";
    owner = "dalmatian";
  };

  services.dalmatian = {
    enable = true;
    environmentFile = config.age.secrets.dalmatian.path;
  };

  scottylabs.postgresql.databases = [
    "dalmatian"
  ];
}
