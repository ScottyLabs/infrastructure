{
  flake.modules.nixos.deploy-01-configuration = {
    networking.hostName = "deploy-01";

    # Campus Cloud VM (dept:scottylabs)
    scottylabs.ipAddress = "128.2.25.68";

    # Public ingress tunnel (cloudflared tunnel create deploy-01)
    scottylabs.cloudflared = {
      tunnelId = "1ce95b80-2f68-4136-b3ac-b7e2eab6b4ef";
      originServerName = "kennel.scottylabs.org";
    };

    system.stateVersion = "25.11";
  };
}
