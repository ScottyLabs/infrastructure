{ ... }:

{
  imports = [
    ./alloy.nix
    ./cadvisor.nix
    ./node-exporter.nix
    ./otel-collector.nix
    ./systemd-exporter.nix
  ];

  scottylabs.alloy.enable = true;
  scottylabs.cadvisor.enable = true;
  scottylabs.nodeExporter.enable = true;
  scottylabs.otelCollector.enable = true;
  scottylabs.systemdExporter.enable = true;
}
