{
  flake.modules.nixos.scottylabs-ci-01-configuration = {
    scottylabs.ipAddress = "172.24.97.83";
    scottylabs.bastion = "infra-01.scottylabs.org";

    system.stateVersion = "26.11";
  };
}
