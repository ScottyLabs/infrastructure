{
  flake.modules.nixos.tailnet-client =
    {
      config,
      pkgs,
      ...
    }:

    {
      services.tailscale = {
        enable = true;
        openFirewall = true;
        authKeyFile = "/run/credentials/tailscaled.service/HEADSCALE_AUTHKEY";
        extraUpFlags = [
          "--login-server=https://headscale.scottylabs.org"
          "--hostname=${config.networking.hostName}"
        ];
      };

      systemd.services.tailscaled.vault.infraSecrets.HEADSCALE_AUTHKEY = {
        path = "headscale";
        key = "HEADSCALE_AUTHKEY";
      };

      networking.firewall.trustedInterfaces = [ "tailscale0" ];

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
          NETDEV=$(${pkgs.iproute2}/bin/ip -o route get 8.8.8.8 | cut -f 5 -d " ")
          if [ -n "$NETDEV" ]; then
            ${pkgs.ethtool}/bin/ethtool -K $NETDEV rx-udp-gro-forwarding on rx-gro-list off || true
          fi
        '';
      };
    };

  flake.modules.darwin.tailnet-client =
    { config, ... }:

    {
      age.secrets.headscale-authkey.file = ../../secrets/headscale-authkey.age;

      services.tailscale = {
        enable = true;
        authKeyFile = config.age.secrets.headscale-authkey.path;
        extraUpFlags = [
          "--login-server=https://headscale.scottylabs.org"
          "--hostname=${config.networking.hostName}"
        ];
      };
    };
}
