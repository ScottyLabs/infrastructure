{ dalmatian, ... }:

{
  imports = [
    dalmatian.nixosModules.default
  ];

  scottylabs.bao-agent = {
    enable = true;
    secrets.dalmatian = {
      project = "dalmatian";
      user = "dalmatian";
    };
  };

  services.dalmatian = {
    enable = false;
    environmentFile = "/run/secrets/dalmatian.env";
  };

  systemd.services.dalmatian = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };

  scottylabs.postgresql.databases = [ "dalmatian" ];
}
