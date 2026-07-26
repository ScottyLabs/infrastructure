{ grafana, ... }:
{
  flake.modules.nixos.node-exporter =
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
    };

  scottylabs.observability = {
    dashboards = [
      {
        folder = "infra";
        name = "hosts";
        source = grafana.dashboard {
          title = "Hosts";
          uid = "infra-hosts";
          panels = [
            (grafana.timeseries {
              title = "CPU usage by host";
              pos = {
                h = 8;
                w = 12;
                x = 0;
                y = 0;
              };
              targets = [
                (grafana.target {
                  expr = "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
                  legend = "{{instance}}";
                })
              ];
              defaults = {
                unit = "percent";
                min = 0;
                max = 100;
              };
            })
            (grafana.timeseries {
              title = "Memory usage by host";
              pos = {
                h = 8;
                w = 12;
                x = 12;
                y = 0;
              };
              targets = [
                (grafana.target {
                  expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
                  legend = "{{instance}}";
                })
              ];
              defaults = {
                unit = "percent";
                min = 0;
                max = 100;
              };
            })
            (grafana.timeseries {
              title = "Load average (1m)";
              pos = {
                h = 8;
                w = 12;
                x = 0;
                y = 8;
              };
              targets = [
                (grafana.target {
                  expr = "node_load1";
                  legend = "{{instance}}";
                })
              ];
              defaults.unit = "short";
            })
            (grafana.timeseries {
              title = "Swap usage";
              pos = {
                h = 8;
                w = 12;
                x = 12;
                y = 8;
              };
              targets = [
                (grafana.target {
                  expr = "(1 - (node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)) * 100";
                  legend = "{{instance}}";
                })
              ];
              defaults = {
                unit = "percent";
                min = 0;
                max = 100;
              };
            })
            (grafana.timeseries {
              title = "Root filesystem usage";
              pos = {
                h = 8;
                w = 12;
                x = 0;
                y = 16;
              };
              targets = [
                (grafana.target {
                  expr = "(1 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"})) * 100";
                  legend = "{{instance}}";
                })
              ];
              defaults = {
                unit = "percent";
                min = 0;
                max = 100;
              };
            })
            (grafana.timeseries {
              title = "Disk I/O bytes/sec";
              pos = {
                h = 8;
                w = 12;
                x = 12;
                y = 16;
              };
              targets = [
                (grafana.target {
                  expr = "rate(node_disk_read_bytes_total[5m])";
                  legend = "read {{instance}} {{device}}";
                })
                (grafana.target {
                  expr = "rate(node_disk_written_bytes_total[5m])";
                  legend = "write {{instance}} {{device}}";
                })
              ];
              defaults.unit = "Bps";
            })
            (grafana.timeseries {
              title = "Network throughput";
              pos = {
                h = 8;
                w = 12;
                x = 0;
                y = 24;
              };
              targets = [
                (grafana.target {
                  expr = "rate(node_network_receive_bytes_total{device!~\"lo|veth.*|docker.*\"}[5m])";
                  legend = "rx {{instance}} {{device}}";
                })
                (grafana.target {
                  expr = "rate(node_network_transmit_bytes_total{device!~\"lo|veth.*|docker.*\"}[5m])";
                  legend = "tx {{instance}} {{device}}";
                })
              ];
              defaults.unit = "Bps";
            })
            (grafana.stat {
              title = "Uptime";
              pos = {
                h = 8;
                w = 12;
                x = 12;
                y = 24;
              };
              targets = [
                (grafana.target {
                  expr = "time() - node_boot_time_seconds";
                  legend = "{{instance}}";
                })
              ];
              options = {
                graphMode = "none";
                colorMode = "value";
                textMode = "value_and_name";
                reduceOptions.calcs = [ "lastNotNull" ];
              };
              defaults = {
                unit = "s";
                color = {
                  mode = "fixed";
                  fixedColor = "green";
                };
              };
            })
            (grafana.timeseries {
              title = "btrfs allocation by host";
              pos = {
                h = 8;
                w = 12;
                x = 0;
                y = 32;
              };
              targets = [
                (grafana.target {
                  expr = "(sum by (instance) (node_btrfs_size_bytes * node_btrfs_allocation_ratio) / sum by (instance) (node_btrfs_device_size_bytes)) * 100";
                  legend = "{{instance}}";
                })
              ];
              defaults = {
                unit = "percent";
                min = 0;
                max = 100;
              };
            })
          ];
        };
      }
    ];
    alerts.rules = [
      {
        name = "host-down";
        source = grafana.promAlert {
          name = "hosts";
          uid = "infra-host-down";
          title = "Host down";
          expr = "up{job=~\"node|kennel|prometheus|loki|tempo|grafana\"} == bool 0";
          severity = "critical";
          summary = "{{ $labels.instance }} is not reporting metrics";
          duration = "5m";
          from = 600;
        };
      }
      {
        name = "disk-full";
        source = grafana.thresholdAlert {
          name = "hosts";
          uid = "infra-disk-full";
          title = "Root filesystem >75% full";
          expr = "1 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"})";
          threshold = 0.75;
          op = "gt";
          severity = "critical";
          summary = "{{ $labels.instance }} root filesystem is {{ $values.A.Value | humanizePercentage }} full (threshold 75%)";
          duration = "5m";
        };
      }
      {
        name = "memory-pressure";
        source = grafana.thresholdAlert {
          name = "hosts";
          uid = "infra-memory-pressure";
          title = "Memory usage >85%";
          expr = "1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)";
          threshold = 0.85;
          op = "gt";
          severity = "warning";
          summary = "{{ $labels.instance }} memory usage is {{ $values.A.Value | humanizePercentage }}";
          duration = "10m";
        };
      }
    ];
  };
}
