{ grafana, ... }:
{
  flake.modules.nixos.uptime-kuma =
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
    };

  scottylabs.observability.alerts.rules = [
    {
      name = "uptime-kuma-monitor-down";
      source = grafana.promAlert {
        name = "uptime-kuma";
        uid = "infra-uptime-kuma-monitor-down";
        title = "Uptime Kuma monitor down";
        expr = "monitor_status == bool 0";
        severity = "critical";
        summary = "{{ $labels.monitor_name }} appears down";
        duration = "5m";
        annotations = {
          description = ''
            Prometheus reports monitor_status == 0 for this Uptime Kuma target
            name={{ $labels.monitor_name }}, type={{ $labels.monitor_type }}.
            URL or host details are in dashboard labels monitor_url/monitor_hostname.
          '';
        };
      };
    }
  ];
}
