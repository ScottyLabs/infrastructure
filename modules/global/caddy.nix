{ grafana, ... }:
{
  flake.modules.nixos.caddy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services.caddy = {
        # cloudflare for DNS-01 renewal of proxied vhosts, security for the garage webadmin portal
        package = pkgs.caddy.withPlugins {
          plugins = [
            "github.com/caddy-dns/cloudflare@v0.2.4"
            "github.com/greenpau/caddy-security@v1.1.62"
          ];
          hash = "sha256-PshaL6GkOxtx0Z8sm2+tQiyiFRvQaOWV1dLS/dR7g0M=";
        };
        globalConfig = ''
          metrics

          acme_dns cloudflare {env.CF_DNS_API_TOKEN}
        '';
      };

      systemd.services = lib.mkIf config.services.caddy.enable {
        caddy.vault.environmentTemplate = ''
          {{ with secret "secret/data/infra/cloudflare-caddy" }}CF_DNS_API_TOKEN={{ .Data.data.TOKEN }}{{ end }}
        '';
      };
    };

  scottylabs.observability.dashboards = [
    {
      folder = "infra";
      name = "caddy";
      source = grafana.dashboard {
        title = "Caddy / HTTP traffic";
        uid = "infra-caddy";
        panels = [
          (grafana.stat {
            title = "Total requests/sec";
            pos = {
              h = 6;
              w = 6;
              x = 0;
              y = 0;
            };
            targets = [ (grafana.target { expr = "sum(rate(caddy_http_requests_total[5m]))"; }) ];
            defaults.unit = "reqps";
          })
          (grafana.stat {
            title = "5xx error rate";
            pos = {
              h = 6;
              w = 6;
              x = 6;
              y = 0;
            };
            targets = [
              (grafana.target { expr = "sum(rate(caddy_http_requests_total{code=~\"5..\"}[5m]))"; })
            ];
            defaults = {
              unit = "reqps";
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                  {
                    color = "yellow";
                    value = 0.01;
                  }
                  {
                    color = "red";
                    value = 0.1;
                  }
                ];
              };
            };
          })
          (grafana.timeseries {
            title = "Request rate by status code";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 0;
            };
            targets = [
              (grafana.target {
                expr = "sum by (code) (rate(caddy_http_requests_total[5m]))";
                legend = "{{code}}";
              })
            ];
            defaults = {
              unit = "reqps";
              custom = {
                stacking = {
                  mode = "normal";
                };
              };
            };
          })
          (grafana.timeseries {
            title = "Request rate by server";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 8;
            };
            targets = [
              (grafana.target {
                expr = "sum by (server) (rate(caddy_http_requests_total[5m]))";
                legend = "{{server}}";
              })
            ];
            defaults.unit = "reqps";
          })
          (grafana.timeseries {
            title = "Response time percentiles (p50/p95/p99)";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 8;
            };
            targets = [
              (grafana.target {
                expr = "histogram_quantile(0.50, sum by (le) (rate(caddy_http_request_duration_seconds_bucket[5m])))";
                legend = "p50";
              })
              (grafana.target {
                expr = "histogram_quantile(0.95, sum by (le) (rate(caddy_http_request_duration_seconds_bucket[5m])))";
                legend = "p95";
              })
              (grafana.target {
                expr = "histogram_quantile(0.99, sum by (le) (rate(caddy_http_request_duration_seconds_bucket[5m])))";
                legend = "p99";
              })
            ];
            defaults.unit = "s";
          })
          (grafana.timeseries {
            title = "5xx by server";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 16;
            };
            targets = [
              (grafana.target {
                expr = "sum by (server) (rate(caddy_http_requests_total{code=~\"5..\"}[5m]))";
                legend = "{{server}}";
              })
            ];
            defaults.unit = "reqps";
          })
          (grafana.timeseries {
            title = "Requests in flight";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 16;
            };
            targets = [
              (grafana.target {
                expr = "sum by (server) (caddy_http_requests_in_flight)";
                legend = "{{server}}";
              })
            ];
            defaults.unit = "short";
          })
        ];
      };
    }
  ];
}
