{
  flake.modules.nixos.scottylabs-infra-03-configuration = {
    scottylabs.ipAddress = "172.24.97.83";
    scottylabs.bastion = "infra-01.scottylabs.org";

    system.stateVersion = "26.11";
  };
}
