{ lib, groupme-mirror, ... }:

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

    # Create a static user because groupme-mirror uses a dynamic one
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "groupme-mirror";
      Group = "groupme-mirror";
    };
  };

  users.users.groupme-mirror = {
    isSystemUser = true;
    group = "groupme-mirror";
  };
  users.groups.groupme-mirror = { };
}
