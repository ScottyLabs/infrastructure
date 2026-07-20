{
  flake.modules.nixos.infra-01-configuration = {
    networking.hostName = "infra-01";

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    system.stateVersion = "25.11";
  };
}
