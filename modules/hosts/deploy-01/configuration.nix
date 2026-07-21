{
  flake.modules.nixos.deploy-01-configuration = {
    networking.hostName = "deploy-01";

    # Campus Cloud VM (dept:scottylabs)
    scottylabs.publicIp = "128.2.25.68";

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    system.stateVersion = "25.11";
  };
}
