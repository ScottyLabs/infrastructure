{ config, ... }:
let
  obs = config.scottylabs.observability;
in
{
  flake.modules.nixos.grafana =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.grafana;

      renderSource =
        ext: item:
        if builtins.isAttrs item.source then
          pkgs.writeText "${item.name}.${ext}" (builtins.toJSON item.source)
        else
          item.source;

      dashboardsDir = pkgs.linkFarm "grafana-dashboards" (
        map (d: {
          name = "${d.folder}/${d.name}.json";
          path = renderSource "json" d;
        }) obs.dashboards
      );

      alertDir =
        kind: items:
        pkgs.linkFarm "grafana-alerts-${kind}" (
          map (a: {
            name = "${a.name}.yaml";
            path = renderSource "yaml" a;
          }) items
        );
    in
    {
      options.scottylabs.grafana = {
        enable = lib.mkEnableOption "Grafana visualization frontend";

        domain = lib.mkOption {
          type = lib.types.str;
          default = "grafana.scottylabs.org";
        };

        httpPort = lib.mkOption {
          type = lib.types.port;
          default = 3000;
        };

        oidcSecretFile = lib.mkOption {
          type = lib.types.path;
          default = "/run/credentials/grafana.service/oidc";
          description = "Path to the file containing the Keycloak OIDC client_secret.";
        };

        secretKeyFile = lib.mkOption {
          type = lib.types.path;
          default = "/run/credentials/grafana.service/secretkey";
          description = "Path to the file containing the Grafana security.secret_key value.";
        };

        prometheusUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://localhost:9090";
        };

        lokiUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://localhost:3101";
        };

        tempoUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://localhost:3200";
        };
      };

      config = lib.mkIf cfg.enable {
        services.grafana = {
          enable = true;

          settings = {
            server = {
              http_addr = "127.0.0.1";
              http_port = cfg.httpPort;
              root_url = "https://${cfg.domain}";
              inherit (cfg) domain;
            };

            analytics.reporting_enabled = false;

            security.secret_key = "$__file{${cfg.secretKeyFile}}";

            users = {
              allow_sign_up = false;
              allow_org_create = false;
              auto_assign_org = true;
              auto_assign_org_role = "Viewer";
              viewers_can_edit = true;
            };

            auth = {
              disable_login_form = true;
              oauth_auto_login = true;
            };

            "auth.basic".enabled = false;

            "auth.generic_oauth" = {
              enabled = true;
              name = "Keycloak";
              client_id = "grafana";
              client_secret = "$__file{${cfg.oidcSecretFile}}";
              scopes = "openid profile email";
              auth_url = "https://idp.scottylabs.org/realms/scottylabs/protocol/openid-connect/auth";
              token_url = "https://idp.scottylabs.org/realms/scottylabs/protocol/openid-connect/token";
              api_url = "https://idp.scottylabs.org/realms/scottylabs/protocol/openid-connect/userinfo";
              use_pkce = true;
              tls_skip_verify_insecure = false;
              allow_assign_grafana_admin = true;
              role_attribute_path = "contains(groups[*], '/projects/devops/admins') && 'GrafanaAdmin' || 'Viewer'";
              role_attribute_strict = true;
            };
          };

          provision = {
            enable = true;

            datasources.settings.datasources = [
              {
                name = "Prometheus";
                type = "prometheus";
                uid = "prometheus";
                url = cfg.prometheusUrl;
                isDefault = true;
              }
              {
                name = "Loki";
                type = "loki";
                uid = "loki";
                url = cfg.lokiUrl;
                jsonData.derivedFields = [
                  {
                    datasourceUid = "tempo";
                    matcherRegex = "trace_id=(\\w+)";
                    name = "TraceID";
                    url = "\${__value.raw}";
                  }
                ];
              }
              {
                name = "Tempo";
                type = "tempo";
                uid = "tempo";
                url = cfg.tempoUrl;
                jsonData = {
                  tracesToLogsV2 = {
                    datasourceUid = "loki";
                    spanStartTimeShift = "-1m";
                    spanEndTimeShift = "1m";
                    tags = [
                      {
                        key = "service.name";
                        value = "service_name";
                      }
                    ];
                  };
                };
              }
            ];

            dashboards.settings.providers = [
              {
                name = "scottylabs";
                type = "file";
                updateIntervalSeconds = 30;
                allowUiUpdates = false;
                disableDeletion = true;
                options = {
                  path = dashboardsDir;
                  foldersFromFilesStructure = true;
                };
              }
            ];

            alerting = {
              rules.path = alertDir "rules" obs.alerts.rules;
              contactPoints.path = alertDir "contact-points" obs.alerts.contactPoints;
              policies.path = alertDir "policies" obs.alerts.policies;
            };
          };
        };

        services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
          reverse_proxy 127.0.0.1:${toString cfg.httpPort}
        '';
      };
    };
}
