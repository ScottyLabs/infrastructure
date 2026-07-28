{
  flake.modules.nixos.infra-01-configuration = {
    networking.hostName = "infra-01";

    # Campus Cloud VM (dept:scottylabs)
    scottylabs.publicIp = "128.2.25.63";

    # Public ingress tunnel (cloudflared tunnel create infra-01)
    scottylabs.cloudflared = {
      tunnelId = "9fe5c8ba-e130-4a52-9f9f-511ddbb4c91d";
      originServerName = "idp.scottylabs.org";
    };

    # Headscale is served directly
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    system.stateVersion = "25.11";
  };
}
