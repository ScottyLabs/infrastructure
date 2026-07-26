{ grafana, ... }:
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

  scottylabs.observability = {
    dashboards = [
      {
        folder = "infra";
        name = "service-health";
        source = grafana.dashboard {
          title = "Service health";
          uid = "infra-service-health";
          panels = [
            (grafana.stat {
              title = "Failed units (total)";
              pos = {
                h = 6;
                w = 6;
                x = 0;
                y = 0;
              };
              targets = [
                (grafana.target { expr = "sum(systemd_unit_state{state=\"failed\"} == 1) or vector(0)"; })
              ];
              defaults = {
                unit = "short";
                thresholds = {
                  mode = "absolute";
                  steps = [
                    {
                      color = "green";
                      value = null;
                    }
                    {
                      color = "red";
                      value = 1;
                    }
                  ];
                };
              };
            })
            (grafana.stat {
              title = "Active units (total)";
              pos = {
                h = 6;
                w = 6;
                x = 6;
                y = 0;
              };
              targets = [ (grafana.target { expr = "sum(systemd_unit_state{state=\"active\"} == 1)"; }) ];
              defaults.unit = "short";
            })
            (grafana.table {
              title = "Currently failed units";
              pos = {
                h = 10;
                w = 12;
                x = 12;
                y = 0;
              };
              targets = [
                (grafana.target {
                  expr = "systemd_unit_state{state=\"failed\"} == 1";
                  format = "table";
                  instant = true;
                })
              ];
              transformations = [
                {
                  id = "organize";
                  options.excludeByName = {
                    "__name__" = true;
                    Time = true;
                    Value = true;
                    state = true;
                    job = true;
                  };
                }
              ];
            })
            (grafana.timeseries {
              title = "Failed units over time";
              pos = {
                h = 8;
                w = 12;
                x = 0;
                y = 6;
              };
              targets = [
                (grafana.target {
                  expr = "sum by (instance) (systemd_unit_state{state=\"failed\"} == 1) or on() (vector(0))";
                  legend = "{{instance}}";
                })
              ];
              defaults = {
                unit = "short";
                min = 0;
              };
            })
            (grafana.table {
              title = "Most recently started units (top 20)";
              pos = {
                h = 12;
                w = 24;
                x = 0;
                y = 14;
              };
              targets = [
                (grafana.target {
                  expr = "topk(20, systemd_unit_start_time_seconds * on(instance, name) group_left systemd_unit_state{state=\"active\"})";
                  format = "table";
                  instant = true;
                })
              ];
              transformations = [
                {
                  id = "organize";
                  options.excludeByName = {
                    "__name__" = true;
                    Time = true;
                    job = true;
                    state = true;
                  };
                }
                {
                  id = "convertFieldType";
                  options.conversions = [
                    {
                      destinationType = "time";
                      targetField = "Value";
                    }
                  ];
                }
                {
                  id = "renameByRegex";
                  options = {
                    regex = "Value";
                    renamePattern = "Started";
                  };
                }
              ];
            })
          ];
        };
      }
    ];
    alerts.rules = [
      {
        name = "service-flapping";
        source = grafana.thresholdAlert {
          name = "services";
          uid = "infra-service-flapping";
          title = "Service flapping (>3 restarts in 1h)";
          expr = "increase(systemd_service_restart_total[1h])";
          threshold = 3;
          op = "gt";
          severity = "warning";
          summary = "{{ $labels.name }} on {{ $labels.instance }} has restarted {{ $values.A.Value }} times in the last hour";
          duration = "5m";
          from = 3600;
        };
      }
    ];
  };
}
