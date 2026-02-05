{ groupme-mirror, ... }:

{
  imports = [
    groupme-mirror.nixosModules.default
  ];

  scottylabs.bao-agent = {
    enable = true;
    secrets.groupme-mirror = {
      project = "groupme-mirror";
      user = "groupme-mirror";
    };
  };

  services.groupme-mirror = {
    enable = true;
    environmentFile = "/run/secrets/groupme-mirror.env";
  };

  systemd.services.groupme-mirror = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };
}
