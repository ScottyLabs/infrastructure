{
  flake.modules.nixos.cloudflared =
    { config, lib, ... }:
    let
      cfg = config.scottylabs.cloudflared;
    in
    {
      options.scottylabs.cloudflared = {
        tunnelId = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Cloudflare Tunnel ID for this host's public ingress";
        };

        originServerName = lib.mkOption {
          type = lib.types.str;
          description = "SNI presented to the local Caddy origin";
        };
      };

      config = lib.mkIf (cfg.tunnelId != null) {
        # Handed to cloudflared via systemd LoadCredential
        age.secrets.cloudflared-tunnel.file =
          ../../secrets + "/${config.networking.hostName}/cloudflared-tunnel.age";

        services.cloudflared = {
          enable = true;
          tunnels.${cfg.tunnelId} = {
            credentialsFile = config.age.secrets.cloudflared-tunnel.path;
            # Catch-all to the local Caddy which owns per-vhost routing
            default = "https://127.0.0.1:443";
            originRequest.originServerName = cfg.originServerName;
          };
        };
      };
    };
}
