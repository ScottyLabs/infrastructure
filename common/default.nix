{ config, ... }:

{
  imports = [
    ./base.nix
    ./users.nix
    ./btrfs.nix
    ./comin.nix
    ./acme.nix
    ./postgresql.nix
    ./valkey.nix
    ./garage.nix
    ./atlantis.nix
    ./cli-proxy-api.nix
    ./tofu.nix
    ./bao-agent.nix
    ./headscale.nix
    ./prometheus.nix
    ./loki.nix
    ./tempo.nix
    ./grafana.nix
    ./otel-collector.nix
    ./node-exporter.nix
    ./systemd-exporter.nix
    ./alloy.nix
    ./cadvisor.nix
    ./uptime-kuma.nix
  ];

  scottylabs.nodeExporter.enable = true;
  scottylabs.systemdExporter.enable = true;
  scottylabs.alloy.enable = true;
  scottylabs.otelCollector.enable = true;
  scottylabs.cadvisor.enable = true;

  services.caddy.globalConfig = ''
    servers {
      metrics
    }
  '';

  # Enforce that each host must have a disk configuration defined
  assertions = [
    {
      assertion = config.disko.devices != { };
      message = "Each host must import a platform module that provides a disk configuration (e.g., platforms/campus-cloud)";
    }
  ];
}
