{
  flake.modules.nixos.observability-agents = {
    scottylabs.alloy.enable = true;
    scottylabs.cadvisor.enable = true;
    scottylabs.nodeExporter.enable = true;
    scottylabs.otelCollector.enable = true;
    scottylabs.systemdExporter.enable = true;
  };
}
