{ grafana, ... }:
{
  flake.modules.nixos.synapse =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.matrix;
    in
    {
      options.scottylabs.matrix.synapse = {
        registrationSecretFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to a file containing the registration shared secret.";
        };

        extraConfigFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to an extra YAML config file merged into synapse (e.g. double-puppet bridge secret).";
        };

        listenPort = lib.mkOption {
          type = lib.types.port;
          default = 8008;
          description = "HTTP listener port for clients and federation.";
        };

        metricsPort = lib.mkOption {
          type = lib.types.port;
          default = 9008;
          description = "Prometheus metrics listener port (synapse exposes /_synapse/metrics).";
        };

        maxUploadSize = lib.mkOption {
          type = lib.types.str;
          default = "100M";
        };
      };

      config = lib.mkIf cfg.enable {
        nixpkgs.config.permittedInsecurePackages = [
          "olm-3.2.16"
        ];

        services.matrix-synapse = {
          enable = true;
          plugins = [ pkgs.matrix-synapse-plugins.matrix-synapse-shared-secret-auth ];
          extraConfigFiles = [ cfg.synapse.extraConfigFile ];
          settings = {
            server_name = cfg.domain;
            public_baseurl = "https://${cfg.matrixDomain}";

            rc_joins = {
              local = {
                per_second = 50;
                burst_count = 200;
              };
              remote = {
                per_second = 10;
                burst_count = 50;
              };
            };

            listeners = [
              {
                port = cfg.synapse.listenPort;
                bind_addresses = [ "127.0.0.1" ];
                type = "http";
                tls = false;
                x_forwarded = true;
                resources = [
                  {
                    names = [
                      "client"
                      "federation"
                    ];
                    compress = true;
                  }
                ];
              }
              {
                port = cfg.synapse.metricsPort;
                bind_addresses = [ "127.0.0.1" ];
                type = "metrics";
                tls = false;
              }
            ];

            database = {
              name = "psycopg2";
              allow_unsafe_locale = true;
              args = {
                host = "/run/postgresql";
                database = "matrix-synapse";
                user = "matrix-synapse";
              };
            };

            max_upload_size = cfg.synapse.maxUploadSize;
            url_preview_enabled = true;
            enable_registration = true;
            enable_registration_without_verification = true;
            enable_metrics = true;
            registration_shared_secret_path = cfg.synapse.registrationSecretFile;

            trusted_key_servers = [
              {
                server_name = "matrix.org";
              }
            ];
          };
        };

        services.caddy.virtualHosts.${cfg.matrixDomain}.extraConfig = ''
          request_body {
            max_size 100MB
          }
          reverse_proxy 127.0.0.1:${toString cfg.synapse.listenPort}
        '';

        networking.firewall.allowedTCPPorts = [ 8448 ];

        scottylabs.postgresql.databases = [ "matrix-synapse" ];
      };
    };

  scottylabs.observability.dashboards = [
    {
      folder = "infra";
      name = "synapse";
      source = grafana.dashboard {
        title = "Synapse";
        uid = "infra-synapse";
        from = "now-6h";
        panels = [
          (grafana.stat {
            title = "Up";
            id = 1;
            pos = {
              h = 4;
              w = 4;
              x = 0;
              y = 0;
            };
            targets = [ (grafana.target { expr = "up{job=\"synapse\"}"; }) ];
            defaults = {
              mappings = [
                {
                  type = "value";
                  options = {
                    "0" = {
                      text = "DOWN";
                      color = "red";
                    };
                    "1" = {
                      text = "UP";
                      color = "green";
                    };
                  };
                }
              ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "red";
                    value = null;
                  }
                  {
                    color = "green";
                    value = 1;
                  }
                ];
              };
            };
          })
          (grafana.stat {
            title = "Daily active users";
            id = 2;
            pos = {
              h = 4;
              w = 5;
              x = 4;
              y = 0;
            };
            targets = [ (grafana.target { expr = "sum(synapse_admin_daily_active_users)"; }) ];
            defaults.unit = "short";
          })
          (grafana.stat {
            title = "Notifier rooms";
            id = 3;
            pos = {
              h = 4;
              w = 5;
              x = 9;
              y = 0;
            };
            targets = [ (grafana.target { expr = "sum(synapse_notifier_rooms)"; }) ];
            defaults.unit = "short";
          })
          (grafana.stat {
            title = "In-flight requests";
            id = 4;
            pos = {
              h = 4;
              w = 5;
              x = 14;
              y = 0;
            };
            targets = [ (grafana.target { expr = "sum(synapse_http_server_in_flight_requests_count)"; }) ];
            defaults.unit = "short";
          })
          (grafana.stat {
            title = "Events persisted";
            id = 5;
            pos = {
              h = 4;
              w = 5;
              x = 19;
              y = 0;
            };
            targets = [ (grafana.target { expr = "sum(synapse_storage_events_persisted_events_total)"; }) ];
            defaults.unit = "short";
          })
          (grafana.timeseries {
            title = "Request rate by servlet";
            id = 10;
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 4;
            };
            targets = [
              (grafana.target {
                expr = "sum by (servlet) (rate(synapse_http_server_response_count_total[5m]))";
                legend = "{{servlet}}";
              })
            ];
            defaults = {
              unit = "reqps";
              min = 0;
              custom = {
                stacking = {
                  mode = "normal";
                };
              };
            };
          })
          (grafana.timeseries {
            title = "Response latency";
            id = 11;
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 4;
            };
            targets = [
              (grafana.target {
                expr = "histogram_quantile(0.50, sum by (le) (rate(synapse_http_server_response_time_seconds_bucket[5m])))";
                legend = "p50";
              })
              (grafana.target {
                expr = "histogram_quantile(0.95, sum by (le) (rate(synapse_http_server_response_time_seconds_bucket[5m])))";
                legend = "p95";
              })
              (grafana.target {
                expr = "histogram_quantile(0.99, sum by (le) (rate(synapse_http_server_response_time_seconds_bucket[5m])))";
                legend = "p99";
              })
            ];
            defaults = {
              unit = "s";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "Federation outbound (transactions & EDUs)";
            id = 20;
            pos = {
              h = 8;
              w = 8;
              x = 0;
              y = 12;
            };
            targets = [
              (grafana.target {
                expr = "sum(rate(synapse_federation_client_sent_transactions_total[5m]))";
                legend = "transactions/s";
              })
              (grafana.target {
                expr = "sum(rate(synapse_federation_client_sent_edus_total[5m]))";
                legend = "edus/s";
              })
            ];
            defaults = {
              unit = "ops";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "Federation inbound staging";
            id = 21;
            pos = {
              h = 8;
              w = 8;
              x = 8;
              y = 12;
            };
            targets = [
              (grafana.target {
                expr = "sum(synapse_federation_server_number_inbound_pdu_in_staging)";
                legend = "PDUs in staging";
              })
              (grafana.target {
                expr = "sum(synapse_federation_server_oldest_inbound_pdu_in_staging)";
                legend = "oldest staging ms";
              })
            ];
            defaults = {
              unit = "short";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "Events persisted";
            id = 22;
            pos = {
              h = 8;
              w = 8;
              x = 16;
              y = 12;
            };
            targets = [
              (grafana.target {
                expr = "sum(rate(synapse_storage_events_persisted_events_total[5m]))";
                legend = "events/s";
              })
            ];
            defaults = {
              unit = "ops";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "Event processing lag";
            id = 30;
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 20;
            };
            targets = [
              (grafana.target {
                expr = "max by (name) (synapse_event_processing_lag)";
                legend = "{{name}}";
              })
            ];
            defaults = {
              unit = "ms";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "DB query time p95 by verb";
            id = 31;
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 20;
            };
            targets = [
              (grafana.target {
                expr = "histogram_quantile(0.95, sum by (le, verb) (rate(synapse_storage_query_time_bucket[5m])))";
                legend = "{{verb}}";
              })
            ];
            defaults = {
              unit = "s";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "Background processes in flight";
            id = 40;
            pos = {
              h = 7;
              w = 12;
              x = 0;
              y = 28;
            };
            targets = [
              (grafana.target {
                expr = "sum by (name) (synapse_background_process_in_flight_count)";
                legend = "{{name}}";
              })
            ];
            defaults = {
              unit = "short";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "Process CPU (user + system)";
            id = 41;
            pos = {
              h = 7;
              w = 12;
              x = 12;
              y = 28;
            };
            targets = [
              (grafana.target {
                expr = "rate(process_cpu_user_seconds_total{job=\"synapse\"}[5m])";
                legend = "user";
              })
              (grafana.target {
                expr = "rate(process_cpu_system_seconds_total{job=\"synapse\"}[5m])";
                legend = "system";
              })
              (grafana.target {
                expr = "rate(process_cpu_user_seconds_total{job=\"synapse\"}[5m]) + rate(process_cpu_system_seconds_total{job=\"synapse\"}[5m])";
                legend = "total";
              })
            ];
            defaults = {
              unit = "percentunit";
              min = 0;
            };
          })
        ];
      };
    }
  ];
}
