{
  flake.modules.nixos.deploy-01-configuration = {
    networking.hostName = "deploy-01";

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    system.stateVersion = "25.11";
  };
}
