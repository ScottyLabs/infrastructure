{
  flake.modules.nixos.systemd-exporter =
    {
      config,
      lib,
      ...
    }:

    let
      cfg = config.scottylabs.systemdExporter;
    in
    {
      options.scottylabs.systemdExporter = {
        enable = lib.mkEnableOption "Prometheus systemd_exporter";

        port = lib.mkOption {
          type = lib.types.port;
          default = 9558;
        };

        unitWhitelist = lib.mkOption {
          type = lib.types.str;
          default = "(kennel.*|caddy|postgresql|valkey|garage|loki|tempo|grafana|prometheus|opentelemetry-collector|promtail)\\.(service|slice)";
          description = "Regex matched against unit names to limit cardinality.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.prometheus.exporters.systemd = {
          enable = true;
          inherit (cfg) port;
          extraFlags = [
            "--systemd.collector.unit-include=${cfg.unitWhitelist}"
            "--systemd.collector.enable-restart-count"
          ];
        };
      };
    };
}
