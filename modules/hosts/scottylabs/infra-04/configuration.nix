{
  flake.modules.darwin.scottylabs-infra-04-configuration = {
    scottylabs.ipAddress = "172.24.96.249";
    scottylabs.bastion = "infra-01.scottylabs.org";

    system.primaryUser = "scottylabs";
    system.stateVersion = 6;
  };
}
