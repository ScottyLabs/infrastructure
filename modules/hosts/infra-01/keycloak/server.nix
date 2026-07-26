{ config, grafana, ... }:
{
  flake.modules.nixos.infra-01-keycloak =
    {
      config,
      pkgs,
      inputs,
      ...
    }:

    let
      keycloak-minecraft-idp = pkgs.fetchurl {
        url = "https://github.com/groundsgg/keycloak-minecraft-idp/releases/download/v1.1.3/keycloak-minecraft-idp-1.1.3.jar";
        hash = "sha256-tL+snexMXmrNTv6uFvZZbpfDQ+MQsOICAVkvDGHiR7U=";
      };
    in
    {
      nixpkgs.overlays = [
        (_: prev: {
          inherit
            (import inputs.nixpkgs-keycloak {
              inherit (prev.stdenv.hostPlatform) system;
              inherit (prev) config;
            })
            keycloak
            ;
        })
      ];

      age.secrets.keycloak = {
        file = ../../../../secrets/infra-01/keycloak.age;
        mode = "0400";
      };

      systemd.services.keycloak.serviceConfig.EnvironmentFile = config.age.secrets.keycloak.path;

      services.keycloak = {
        enable = true;
        database = {
          type = "postgresql";
          createLocally = false;
          host = "/run/postgresql";
          name = "keycloak";
          username = "keycloak";
          useSSL = false;
        };

        settings = {
          hostname = "https://idp.scottylabs.org";
          hostname-strict = true;
          hostname-backchannel-dynamic = true;
          proxy-headers = "xforwarded";
          http-enabled = true;
          http-host = "127.0.0.1";
          http-port = 8080;
          log-level = "org.keycloak.broker:debug,org.keycloak.events:debug,org.keycloak.saml:debug,org.keycloak.federation.ldap:debug";
          features = "scripts";
          metrics-enabled = true;
          health-enabled = true;
          http-management-port = 9092;
        };

        themes = {
          terrier = pkgs.runCommand "keycloak-terrier-theme" { } ''
            cp -r ${inputs.keycloak-theme}/themes/scottylabs $out
          '';
        };

        plugins = with config.services.keycloak.package.plugins; [
          apple-identity-provider-keycloak
          keycloak-discord
          keycloak-remember-me-authenticator
          keycloak-minecraft-idp

          # Unix socket auth
          junixsocket-common
          junixsocket-native-common
        ];
      };

      services.caddy = {
        enable = true;
        virtualHosts."idp.scottylabs.org".extraConfig = ''
          reverse_proxy 127.0.0.1:8080 {
            header_up X-Forwarded-Port {server_port}
          }
        '';
      };

      scottylabs.postgresql.databases = [ "keycloak" ];
    };

  scottylabs.observability.dashboards = [
    {
      folder = "infra";
      name = "keycloak";
      source = grafana.dashboard {
        title = "Keycloak";
        uid = "infra-keycloak";
        from = "now-6h";
        panels = [
          (grafana.timeseries {
            title = "Login-action activity by status";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 0;
            };
            targets = [
              (grafana.target {
                expr = "sum by (code) (rate(keycloak_response_total{resource=~\".*login-actions.*\"}[5m]))";
                legend = "{{code}}";
              })
            ];
            defaults.unit = "ops";
          })
          (grafana.timeseries {
            title = "OIDC token-endpoint activity";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 0;
            };
            targets = [
              (grafana.target {
                expr = "sum by (code) (rate(keycloak_response_total{resource=~\".*openid-connect.*\",method=\"POST\"}[5m]))";
                legend = "{{code}}";
              })
            ];
            defaults.unit = "ops";
          })
          (grafana.timeseries {
            title = "Total HTTP response rate by status";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 8;
            };
            targets = [
              (grafana.target {
                expr = "sum by (code) (rate(keycloak_response_total[5m]))";
                legend = "{{code}}";
              })
            ];
            defaults = {
              unit = "ops";
              custom = {
                stacking = {
                  mode = "normal";
                };
              };
            };
          })
          (grafana.timeseries {
            title = "Error responses (4xx + 5xx)";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 8;
            };
            targets = [
              (grafana.target {
                expr = "sum by (code, resource) (rate(keycloak_response_errors_total[5m]))";
                legend = "{{code}} {{resource}}";
              })
            ];
            defaults.unit = "ops";
          })
          (grafana.timeseries {
            title = "JVM heap used / committed / max";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 16;
            };
            targets = [
              (grafana.target {
                expr = "base_memory_used_heap_bytes";
                legend = "used";
              })
              (grafana.target {
                expr = "base_memory_committedHeap_bytes";
                legend = "committed";
              })
              (grafana.target {
                expr = "base_memory_maxHeap_bytes";
                legend = "max";
              })
            ];
            defaults.unit = "bytes";
          })
          (grafana.timeseries {
            title = "DB connection pool";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 16;
            };
            targets = [
              (grafana.target {
                expr = "agroal_active_count";
                legend = "active";
              })
              (grafana.target {
                expr = "agroal_available_count";
                legend = "available";
              })
            ];
            defaults.unit = "short";
          })
          (grafana.timeseries {
            title = "GC time rate";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 24;
            };
            targets = [
              (grafana.target {
                expr = "rate(base_gc_time[5m])";
                legend = "{{name}}";
              })
            ];
            defaults.unit = "ms";
          })
          (grafana.timeseries {
            title = "Cache size";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 24;
            };
            targets = [
              (grafana.target {
                expr = "cache_size";
                legend = "{{cache}}";
              })
            ];
            defaults.unit = "short";
          })
        ];
      };
    }
  ];

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.keycloak = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/keycloak.tfstate";
            dns.idp = {
              host = "infra-01";
              type = "CNAME";
              comment = "Keycloak";
            };
          }
        ];
      };
    };

  scottylabs.observability.alerts.rules = [
    {
      name = "keycloak-down";
      source = grafana.upAlert {
        name = "keycloak";
        job = "keycloak";
        uid = "infra-keycloak-down";
        title = "Keycloak down";
        severity = "critical";
        summary = "Keycloak (SSO) is not responding to Prometheus scrapes";
        duration = "2m";
      };
    }
  ];
}
