{ internet-archive, ... }:

{
  imports = [
    internet-archive.nixosModules.default
  ];

  scottylabs.bao-agent = {
    enable = true;
    secrets.internet-archive = {
      project = "internet-archive";
      user = "internet-archive";
    };
  };

  services.internet-archive = {
    enable = true;
    environmentFile = "/run/secrets/internet-archive.env";
    presets = [ "soc" ];
    schedule = "weekly";
    debug = true;
  };

  systemd.services.internet-archive = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };
}
