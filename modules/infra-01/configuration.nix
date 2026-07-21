{
  flake.modules.nixos.infra-01-configuration = {
    networking.hostName = "infra-01";

    # Campus Cloud VM (dept:scottylabs)
    scottylabs.publicIp = "128.2.25.63";

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    system.stateVersion = "25.11";
  };
}
