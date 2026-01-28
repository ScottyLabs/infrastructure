{ config, pkgs, ... }:

{
  scottylabs.bao-agent = {
    enable = true;
    infraSecrets.tailscale = {
      path = "tailscale";
      key = "TS_AUTHKEY";
      user = "root";
    };
  };

  # Enable Tailscale and IP forwarding
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    authKeyFile = "/run/secrets/tailscale";
<<<<<<< HEAD
    extraUpFlags = [
      "--ssh"
      "--advertise-exit-node"
    ];
=======
    extraUpFlags = [ "--ssh" ];
>>>>>>> ddead43c49e1d00fb382e4686e0f0a3844a8210b
  };

  systemd.services.tailscaled = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };

  # Open firewall for Tailscale
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  # Tailscale CLI
  environment.systemPackages = [ pkgs.tailscale ];

  # Enable UDP GRO forwarding on boot
  systemd.services.tailscale-udp-gro = {
    description = "Enable UDP GRO forwarding for Tailscale";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Get the default route interface
      NETDEV=$(${pkgs.iproute2}/bin/ip -o route get 8.8.8.8 | cut -f 5 -d " ")
      if [ -n "$NETDEV" ]; then
        ${pkgs.ethtool}/bin/ethtool -K $NETDEV rx-udp-gro-forwarding on rx-gro-list off || true
      fi
    '';
  };
}
