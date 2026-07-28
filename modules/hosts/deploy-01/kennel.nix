{ config, grafana, ... }:
{
  flake.modules.nixos.deploy-01-kennel =
    { config, inputs, ... }:

    {
      imports = [
        inputs.kennel.nixosModules.default
      ];

      # Skip kennel.slice units in switch-to-configuration's failed-unit sweep
      nixpkgs.overlays = [
        (_: prev: {
          switch-to-configuration-ng = prev.switch-to-configuration-ng.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/main.rs \
                --replace-fail 'for (unit, unit_state) in new_active_units {' 'for (unit, unit_state) in new_active_units { if unit.ends_with(".service") { let slice: Result<String, _> = unit_state.proxy.get("org.freedesktop.systemd1.Service", "Slice"); if matches!(slice, Ok(s) if s == "kennel.slice") { continue; } }'
            '';
          });
        })
      ];

      age.secrets.kennel = {
        file = ../../../secrets/deploy-01/kennel.age;
        owner = "kennel";
        group = "kennel";
        mode = "0440";
      };

      age.secrets.kennel-webhook-secret = {
        file = ../../../secrets/deploy-01/kennel-webhook-secret.age;
        owner = "kennel";
        group = "kennel";
        mode = "0400";
      };

      age.secrets.kennel-forgejo-token = {
        file = ../../../secrets/deploy-01/kennel-forgejo-token.age;
        owner = "kennel";
        group = "kennel";
        mode = "0400";
      };

      services.kennel = {
        enable = true;
        package = inputs.kennel.packages.x86_64-linux.kennel;
        devenvPackage = inputs.kennel.packages.x86_64-linux.devenv;
        webhookSecretFile = config.age.secrets.kennel-webhook-secret.path;
        environmentFile = config.age.secrets.kennel.path;
        api.port = 3001;

        # Published for ricochet's return_to allowlist (services.ricochet.allowedHostsFile)
        customDomainsFile = "/run/kennel/custom-domains";

        domains = {
          ephemeral = "scottylabs.net";
          cloudflare = {
            tunnelId = "1ce95b80-2f68-4136-b3ac-b7e2eab6b4ef";
            zones = {
              "scottylabs.org" = "ab365d7cec88f972e0b26bf59afd174f";
              "cmu.quest" = "2bf8696c7e2fdc56f9b9e98443f001cc";
              "cmu.lol" = "dbedf6cff671263c0d6f69b482895ee4";
              "cmu.courses" = "a3c2419a7e47cdc909022c5815310013";
              "cmu.dev" = "9ae67b02fb7f5a546a8fd18527115ea5";
              "cmuhousing.com" = "90331dc9edd007e59c828faa3b8d73a9";
              "cmumaps.com" = "a0686a6fe9f1e181d0c1dcdf9c293a9b";
              "cmueats.com" = "78a8413b3e73553f7def8cefe1bdc386";
              "cmugpt.com" = "dfe11e930ca4ef3d94cd9f79072315cd";
              "tartan.vote" = "97416783adc55489c6f601bbfaa48936";
              "terrier.build" = "5ec9401ebede43c78ad0167fefd3b862";
            };
          };
        };

        builder.cachix = {
          enable = true;
          cacheName = "scottylabs";
        };

        resources.postgres = {
          enable = true;
          socketDir = "/run/postgresql";
        };

        resources.valkey = {
          enable = true;
          socketPath = "/run/redis-kennel/redis.sock";
        };

        resources.garage = {
          enable = true;
          # Public S3 endpoint clients presign against
          s3Endpoint = "https://s3.kennel.scottylabs.org";
        };

        secrets = {
          enable = true;
          vaultEndpoint = "vault://secrets.scottylabs.org/secret?auth=approle";
        };

        forgejo.apiTokenFile = config.age.secrets.kennel-forgejo-token.path;
      };

      scottylabs.postgresql.databases = [ "kennel" ];
      scottylabs.valkey.servers = [ "kennel" ];

      services.postgresql.ensureUsers = [
        {
          name = "kennel";
          ensureClauses = {
            createdb = true;
            createrole = true;
          };
        }
      ];
    };

  scottylabs.observability = {
    dashboards = [
      {
        folder = "kennel";
        name = "overview";
        source = grafana.dashboard {
          title = "Kennel";
          uid = "kennel-overview";
          tags = [ "kennel" ];
          from = "now-6h";
          panels = [
            (grafana.stat {
              title = "Projects";
              id = 1;
              pos = {
                h = 5;
                w = 4;
                x = 0;
                y = 0;
              };
              targets = [ (grafana.target { expr = "kennel_projects"; }) ];
              defaults = {
                unit = "short";
              };
              options = {
                graphMode = "none";
                colorMode = "value";
                reduceOptions.calcs = [ "lastNotNull" ];
              };
            })
            (grafana.stat {
              title = "Deployments";
              id = 2;
              pos = {
                h = 5;
                w = 4;
                x = 4;
                y = 0;
              };
              targets = [ (grafana.target { expr = "kennel_deployments"; }) ];
              defaults = {
                unit = "short";
                color = {
                  mode = "fixed";
                  fixedColor = "green";
                };
              };
              options = {
                graphMode = "none";
                colorMode = "value";
                reduceOptions.calcs = [ "lastNotNull" ];
              };
            })
            (grafana.stat {
              title = "Failed deployments";
              id = 3;
              pos = {
                h = 5;
                w = 4;
                x = 8;
                y = 0;
              };
              targets = [
                (grafana.target {
                  expr = "count(systemd_unit_state{name=~\"kennel-.*\\\\.service\",state=\"failed\"} == 1) or vector(0)";
                })
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
              options = {
                graphMode = "none";
                colorMode = "value";
                reduceOptions.calcs = [ "lastNotNull" ];
              };
            })
            (grafana.timeseries {
              title = "Build state over time";
              id = 4;
              pos = {
                h = 8;
                w = 12;
                x = 12;
                y = 0;
              };
              targets = [
                (grafana.target {
                  expr = "kennel_builds";
                  legend = "{{status}}";
                })
              ];
              defaults = {
                unit = "short";
                custom.stacking.mode = "normal";
              };
            })
            (grafana.timeseries {
              title = "Queue depth + in-flight";
              id = 5;
              pos = {
                h = 8;
                w = 12;
                x = 0;
                y = 5;
              };
              targets = [
                (grafana.target {
                  expr = "kennel_builds{status=\"queued\"}";
                  legend = "queued";
                })
                (grafana.target {
                  expr = "kennel_builds{status=\"building\"}";
                  legend = "building";
                })
              ];
              defaults = {
                unit = "short";
              };
            })
            (grafana.table {
              title = "Most recently started deployments (top 20)";
              id = 6;
              pos = {
                h = 12;
                w = 12;
                x = 0;
                y = 13;
              };
              targets = [
                (grafana.target {
                  expr = "topk(20, systemd_unit_start_time_seconds{name=~\"kennel-.*\\\\.service\"})";
                  format = "table";
                  instant = true;
                })
              ];
              transformations = [
                {
                  id = "organize";
                  options.excludeByName = {
                    "__name__" = true;
                    "Time" = true;
                    "job" = true;
                    "state" = true;
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
            (grafana.timeseries {
              title = "Restart count (top 10 kennel units)";
              id = 7;
              pos = {
                h = 12;
                w = 12;
                x = 12;
                y = 8;
              };
              targets = [
                (grafana.target {
                  expr = "topk(10, systemd_service_restart_total{name=~\"kennel-.*\\\\.service\"})";
                  legend = "{{name}}";
                })
              ];
              defaults = {
                unit = "short";
              };
            })
            (grafana.table {
              title = "Currently failed kennel units";
              id = 8;
              pos = {
                h = 8;
                w = 24;
                x = 0;
                y = 25;
              };
              targets = [
                (grafana.target {
                  expr = "systemd_unit_state{name=~\"kennel-.*\\\\.service\",state=\"failed\"} == 1";
                  format = "table";
                  instant = true;
                })
              ];
              transformations = [
                {
                  id = "organize";
                  options.excludeByName = {
                    "__name__" = true;
                    "Time" = true;
                    "Value" = true;
                    "state" = true;
                    "job" = true;
                  };
                }
              ];
            })
            (grafana.timeseries {
              title = "CPU usage per deployment";
              id = 10;
              pos = {
                h = 8;
                w = 12;
                x = 0;
                y = 33;
              };
              targets = [
                (grafana.target {
                  expr = "label_replace(rate(container_cpu_usage_seconds_total{id=~\"/kennel\\\\.slice/kennel-.*\\\\.service\",cpu=\"total\"}[5m]), \"unit\", \"$1\", \"id\", \"/kennel\\\\.slice/(.+)\\\\.service\")";
                  legend = "{{unit}}";
                })
              ];
              defaults = {
                unit = "percentunit";
                custom = {
                  stacking.mode = "normal";
                  fillOpacity = 30;
                };
              };
            })
            (grafana.timeseries {
              title = "Memory working set per deployment";
              id = 11;
              pos = {
                h = 8;
                w = 12;
                x = 12;
                y = 33;
              };
              targets = [
                (grafana.target {
                  expr = "label_replace(container_memory_working_set_bytes{id=~\"/kennel\\\\.slice/kennel-.*\\\\.service\"}, \"unit\", \"$1\", \"id\", \"/kennel\\\\.slice/(.+)\\\\.service\")";
                  legend = "{{unit}}";
                })
              ];
              defaults = {
                unit = "bytes";
              };
            })
            (grafana.timeseries {
              title = "Tasks per deployment";
              id = 9;
              pos = {
                h = 8;
                w = 24;
                x = 0;
                y = 41;
              };
              targets = [
                (grafana.target {
                  expr = "systemd_unit_tasks_current{name=~\"kennel-.*\\\\.service\"}";
                  legend = "{{name}}";
                })
              ];
              defaults = {
                unit = "short";
              };
            })
          ];
        };
      }
    ];
    alerts.rules = [
      {
        name = "kennel-deploy-failed";
        source = grafana.promAlert {
          name = "kennel";
          uid = "infra-kennel-deploy-failed";
          title = "Kennel deployment failed";
          expr = "systemd_unit_state{name=~\"kennel-.*\\\\.service\",state=\"failed\"} == bool 1";
          severity = "critical";
          summary = "{{ $labels.name }} on {{ $labels.instance }} is in failed state";
          duration = "5m";
        };
      }
    ];
  };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.kennel = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/kennel.tfstate";
            dns = {
              kennel = {
                tunnel = "deploy-01";
                comment = "Kennel deployment platform";
              };
              "s3.kennel" = {
                tunnel = "deploy-01";
                comment = "Kennel per-deployment garage S3 API";
              };
              "*" = {
                zone = "scottylabs.net";
                tunnel = "deploy-01";
                comment = "Kennel deployment platform wildcard";
              };
            };
            resource.vault_policy.kennel = {
              name = "kennel";
              policy = ''
                path "secret/data/secretspec/+/+/*" {
                  capabilities = ["read"]
                }

                path "secret/metadata/secretspec/+/+/*" {
                  capabilities = ["list", "read"]
                }
              '';
            };

            resource.vault_approle_auth_backend_role.kennel = {
              backend = "approle";
              role_name = "kennel";
              token_policies = [ "\${vault_policy.kennel.name}" ];
              token_ttl = 3600;
              token_max_ttl = 86400;
              secret_id_ttl = 0;
            };

            output.kennel_approle_role_id.value = "\${vault_approle_auth_backend_role.kennel.role_id}";
          }
        ];
      };
    };
}
