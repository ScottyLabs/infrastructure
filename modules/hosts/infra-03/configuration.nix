{
  flake.modules.nixos.infra-03-configuration = {
    networking.hostName = "infra-03";

    scottylabs.ipAddress = "172.24.97.83";
    scottylabs.bastion = "infra-01.scottylabs.org";

    system.stateVersion = "26.11";
  };
}
