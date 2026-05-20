{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.uptime-kuma;
in
{
  options.scottylabs.uptime-kuma = {
    enable = lib.mkEnableOption "Uptime Kuma uptime monitor and status page";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Loopback port for the Uptime Kuma web UI and API.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "uptime.scottylabs.org";
      description = "Public domain for the Uptime Kuma web UI and status pages.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.uptime-kuma = {
      enable = true;
      settings = {
        HOST = "127.0.0.1";
        PORT = toString cfg.port;
      };
    };

    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      reverse_proxy 127.0.0.1:${toString cfg.port}
    '';
  };
}
