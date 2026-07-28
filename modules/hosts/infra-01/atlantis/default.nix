{ config, grafana, ... }:
{
  flake.modules.nixos.infra-01-atlantis =
    { config, pkgs, ... }:
    let
      forgejoProvider = pkgs.stdenvNoCC.mkDerivation {
        pname = "terraform-provider-forgejo";
        version = "1.4.2-team-repository.2";
        src = pkgs.fetchurl {
          url = "https://github.com/ap-1/terraform-provider-forgejo/releases/download/v1.4.2-team-repository.2/terraform-provider-forgejo_1.4.2-team-repository.2_linux_amd64.zip";
          hash = "sha256-GMMlBaarmhOxpgNwDjl+2L65qh1nIT6RFj+JAsGZT5E=";
        };
        nativeBuildInputs = [ pkgs.unzip ];
        sourceRoot = ".";
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          install -Dm755 -t "$out" terraform-provider-forgejo_*
          runHook postInstall
        '';
      };

      # Patched svalabs/forgejo fork, substituted at plan/apply via dev_overrides
      forgejoTfrc = pkgs.writeText "forgejo-dev-overrides.tfrc" ''
        provider_installation {
          dev_overrides {
            "svalabs/forgejo" = "${forgejoProvider}"
          }
          direct {}
        }
      '';
    in
    {
      scottylabs.atlantis = {
        enable = true;
        domain = "atlantis.scottylabs.org";
        environmentFile = config.age.secrets.atlantis.path;
        extraPackages = [
          pkgs.opentofu
          pkgs.nix
          pkgs.go
          pkgs.unzip
          pkgs.curl
          pkgs.cargo
          pkgs.rustc
          pkgs.gcc
        ];
        extraArgs = [
          "--gitea-base-url=https://codeberg.org"
          "--gitea-user=scottylabs-bot"
          "--repo-allowlist=codeberg.org/ScottyLabs/governance,codeberg.org/ScottyLabs/infrastructure"
          "--allow-fork-prs"
          "--default-tf-distribution=opentofu"
          "--write-git-creds"
          "--allow-commands=all"
          "--silence-vcs-status-no-plans"
          "--hide-prev-plan-comments"
          "--enable-diff-markdown-format"
          "--fail-on-pre-workflow-hook-error"
          "--repo-config=${./repo-config.yml}"
        ];
      };

      age.secrets.atlantis = {
        file = ../../../../secrets/infra-01/atlantis.age;
        owner = "atlantis";
        mode = "0400";
      };

      systemd.services.atlantis.serviceConfig.EnvironmentFile = [
        config.age.secrets.tofu-providers.path
      ];

      systemd.services.atlantis.environment = {
        TF_PLUGIN_CACHE_DIR = "/var/lib/atlantis/plugin-cache";
        TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE = "1";
        FORGEJO_TFRC = "${forgejoTfrc}";
      };

      systemd.tmpfiles.rules = [ "d /var/lib/atlantis/plugin-cache 0755 atlantis atlantis -" ];
    };

  scottylabs.observability.dashboards = [
    {
      folder = "infra";
      name = "atlantis";
      source = grafana.dashboard {
        title = "Atlantis";
        uid = "infra-atlantis";
        from = "now-24h";
        panels = [
          (grafana.stat {
            title = "Atlantis up";
            pos = {
              h = 4;
              w = 4;
              x = 0;
              y = 0;
            };
            id = 1;
            targets = [ (grafana.target { expr = "up{job=\"atlantis\"}"; }) ];
            defaults = {
              unit = "short";
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
            title = "Plan success rate (24h)";
            pos = {
              h = 4;
              w = 5;
              x = 4;
              y = 0;
            };
            id = 2;
            targets = [
              (grafana.target {
                expr = "100 * sum(increase({__name__=~\"atlantis_cmd_(autoplan|comment_plan)_execution_success\"}[24h])) / clamp_min(sum(increase({__name__=~\"atlantis_cmd_(autoplan|comment_plan)_execution_(success|error|failure)\"}[24h])), 1)";
              })
            ];
            defaults = {
              unit = "percent";
              min = 0;
              max = 100;
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "red";
                    value = null;
                  }
                  {
                    color = "yellow";
                    value = 80;
                  }
                  {
                    color = "green";
                    value = 95;
                  }
                ];
              };
            };
          })
          (grafana.stat {
            title = "Apply success rate (24h)";
            pos = {
              h = 4;
              w = 5;
              x = 9;
              y = 0;
            };
            id = 3;
            targets = [
              (grafana.target {
                expr = "100 * sum(increase(atlantis_cmd_comment_apply_execution_success[24h])) / clamp_min(sum(increase({__name__=~\"atlantis_cmd_comment_apply_execution_(success|error|failure)\"}[24h])), 1)";
              })
            ];
            defaults = {
              unit = "percent";
              min = 0;
              max = 100;
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "red";
                    value = null;
                  }
                  {
                    color = "yellow";
                    value = 80;
                  }
                  {
                    color = "green";
                    value = 95;
                  }
                ];
              };
            };
          })
          (grafana.stat {
            title = "Apply errors (24h)";
            pos = {
              h = 4;
              w = 5;
              x = 14;
              y = 0;
            };
            id = 4;
            targets = [
              (grafana.target {
                expr = "sum(increase({__name__=~\"atlantis_cmd_comment_apply_execution_(error|failure)\"}[24h])) or vector(0)";
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
                    color = "yellow";
                    value = 1;
                  }
                  {
                    color = "red";
                    value = 5;
                  }
                ];
              };
            };
          })
          (grafana.stat {
            title = "Goroutines";
            pos = {
              h = 4;
              w = 5;
              x = 19;
              y = 0;
            };
            id = 5;
            targets = [
              (grafana.target { expr = "atlantis_scheduled_runtime_cpu_goroutines{job=\"atlantis\"}"; })
            ];
            defaults.unit = "short";
          })
          (grafana.timeseries {
            title = "Operations per minute (success)";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 4;
            };
            id = 10;
            targets = [
              (grafana.target {
                expr = "sum by (__name__) (rate({__name__=~\"atlantis_cmd_.*_execution_success\"}[5m])) * 60";
                legend = "{{__name__}}";
              })
            ];
            defaults = {
              unit = "ops/min";
              min = 0;
              custom = {
                stacking = {
                  mode = "normal";
                };
              };
            };
          })
          (grafana.timeseries {
            title = "Operations per minute (errors + failures)";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 4;
            };
            id = 11;
            targets = [
              (grafana.target {
                expr = "sum by (__name__) (rate({__name__=~\"atlantis_cmd_.*_execution_(error|failure)\"}[5m])) * 60";
                legend = "{{__name__}}";
              })
            ];
            defaults = {
              unit = "ops/min";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "Project execution latency (Tally summary, plan+apply unified)";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 12;
            };
            id = 20;
            targets = [
              (grafana.target {
                expr = "avg(atlantis_project_execution_time{quantile=\"0.5\"})";
                legend = "p50";
              })
              (grafana.target {
                expr = "avg(atlantis_project_execution_time{quantile=\"0.95\"})";
                legend = "p95";
              })
              (grafana.target {
                expr = "avg(atlantis_project_execution_time{quantile=\"0.99\"})";
                legend = "p99";
              })
            ];
            defaults = {
              unit = "s";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "Builder & pull-closed-cleanup throughput";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 12;
            };
            id = 21;
            targets = [
              (grafana.target {
                expr = "rate(atlantis_builder_execution_success[5m]) * 60";
                legend = "builder success/min";
              })
              (grafana.target {
                expr = "rate(atlantis_builder_execution_error[5m]) * 60";
                legend = "builder errors/min";
              })
              (grafana.target {
                expr = "rate(atlantis_pullclosed_cleanup_execution_success[5m]) * 60";
                legend = "pullclosed success/min";
              })
              (grafana.target {
                expr = "rate(atlantis_pullclosed_cleanup_execution_error[5m]) * 60";
                legend = "pullclosed errors/min";
              })
            ];
            defaults = {
              unit = "ops/min";
              min = 0;
            };
          })
          (grafana.table {
            title = "Project executions - success (24h)";
            pos = {
              h = 9;
              w = 12;
              x = 0;
              y = 20;
            };
            id = 30;
            targets = [
              (grafana.target {
                expr = "sum by (project, base_repo, workspace) (increase(atlantis_project_execution_success[24h]))";
                format = "table";
                instant = true;
              })
            ];
            transformations = [
              {
                id = "organize";
                options = {
                  excludeByName = {
                    Time = true;
                    __name__ = true;
                  };
                };
              }
            ];
          })
          (grafana.table {
            title = "Project executions - errors + failures (24h)";
            pos = {
              h = 9;
              w = 12;
              x = 12;
              y = 20;
            };
            id = 31;
            targets = [
              (grafana.target {
                expr = "sum by (project, base_repo, workspace) (increase({__name__=~\"atlantis_project_execution_(error|failure)\"}[24h]))";
                format = "table";
                instant = true;
              })
            ];
            transformations = [
              {
                id = "organize";
                options = {
                  excludeByName = {
                    Time = true;
                    __name__ = true;
                  };
                };
              }
            ];
          })
          (grafana.timeseries {
            title = "Goroutines & GC pauses";
            pos = {
              h = 7;
              w = 12;
              x = 0;
              y = 29;
            };
            id = 40;
            targets = [
              (grafana.target {
                expr = "atlantis_scheduled_runtime_cpu_goroutines{job=\"atlantis\"}";
                legend = "goroutines";
              })
              (grafana.target {
                expr = "rate(atlantis_scheduled_runtime_memory_gc_pause_total{job=\"atlantis\"}[5m])";
                legend = "gc pause ns/s";
              })
            ];
            defaults = {
              unit = "short";
              min = 0;
            };
          })
          (grafana.timeseries {
            title = "Process memory (Go runtime)";
            pos = {
              h = 7;
              w = 12;
              x = 12;
              y = 29;
            };
            id = 41;
            targets = [
              (grafana.target {
                expr = "atlantis_scheduled_runtime_memory_alloc{job=\"atlantis\"}";
                legend = "heap alloc";
              })
              (grafana.target {
                expr = "atlantis_scheduled_runtime_memory_heap_inuse{job=\"atlantis\"}";
                legend = "heap in-use";
              })
              (grafana.target {
                expr = "atlantis_scheduled_runtime_memory_sys{job=\"atlantis\"}";
                legend = "sys (reserved)";
              })
            ];
            defaults = {
              unit = "bytes";
              min = 0;
            };
          })
        ];
      };
    }
  ];

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.atlantis = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/atlantis.tfstate";
            dns.atlantis = {
              tunnel = "infra-01";
              comment = "Atlantis OpenTofu PR automation";
            };
          }
        ];
      };
    };
}
