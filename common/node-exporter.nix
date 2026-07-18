{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.nodeExporter;
in
{
  options.scottylabs.nodeExporter = {
    enable = lib.mkEnableOption "Prometheus node_exporter";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9100;
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      inherit (cfg) port;
      listenAddress = "0.0.0.0";
      enabledCollectors = [
        "systemd"
        "processes"
        "cgroups"
      ];
    };
  };
}
