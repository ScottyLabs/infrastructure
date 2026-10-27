{
  flake.modules.darwin.scottylabs-infra-02-configuration = {
    scottylabs.ipAddress = "172.26.160.112";
    scottylabs.bastion = "infra-01.scottylabs.org";

    system.primaryUser = "scottylabs";
    system.stateVersion = 6;
  };
}
