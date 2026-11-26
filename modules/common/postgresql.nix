{ grafana, ... }:
{
  flake.modules.nixos.postgresql =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.postgresql;

      # Package attribute = name used by CREATE EXTENSION
      extensions = {
        pg_uuidv7 = "pg_uuidv7";
        pgvector = "vector";
        postgis = "postgis";
      };

      # Lets database owners create them without being superuser
      trusted =
        sqlName: pkg:
        pkgs.runCommand "${pkg.pname}-${pkg.version}" { inherit (pkg) pname version; } ''
          cp -rs --no-preserve=mode ${pkg} $out
          control=$out/share/postgresql/extension/${sqlName}.control
          rm $control
          cat ${pkg}/share/postgresql/extension/${sqlName}.control > $control
          echo "trusted = true" >> $control
        '';

      withExtensions = ps: lib.mapAttrsToList (attr: sqlName: trusted sqlName ps.${attr}) extensions;

      # Cluster that postgresql-upgrade migrates from
      previous = pkgs.postgresql_18;
      previousDataDir = "/var/lib/postgresql/${previous.psqlSchema}";

      pg = config.services.postgresql;
    in
    {
      options.scottylabs.postgresql = {
        databases = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "List of databases to create";
          example = [
            "keycloak"
            "vaultwarden"
          ];
        };
      };

      config = lib.mkIf (cfg.databases != [ ]) {
        services.postgresql = {
          enable = true;
          package = pkgs.postgresql_19;
          extensions = withExtensions;
          settings.max_connections = 300;

          initdbArgs = [
            "--locale-provider=builtin"
            "--locale=C.UTF-8"
          ];

          ensureDatabases = cfg.databases;
          ensureUsers = map (name: {
            inherit name;
            ensureDBOwnership = true;
          }) cfg.databases;
        };

        systemd.services.postgresql-upgrade = {
          description = "Upgrade PostgreSQL ${previous.psqlSchema} cluster to ${pg.package.psqlSchema}";
          requiredBy = [ "postgresql.service" ];
          before = [ "postgresql.service" ];
          unitConfig.ConditionPathExists = [
            "${previousDataDir}/PG_VERSION"
            "!${pg.dataDir}/PG_VERSION"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "postgres";
            Group = "postgres";
            UMask = "0027";
            RuntimeDirectory = "postgresql-upgrade";
            WorkingDirectory = "/var/lib/postgresql";
            TimeoutStartSec = "infinity";
          };
          script = ''
            staging=${pg.dataDir}.upgrade
            rm -rf "$staging"
            ${pg.finalPackage}/bin/initdb -D "$staging" -U ${pg.superUser} ${lib.escapeShellArgs pg.initdbArgs}
            ${pg.finalPackage}/bin/pg_upgrade \
              --old-bindir ${previous.withPackages withExtensions}/bin \
              --new-bindir ${pg.finalPackage}/bin \
              --old-datadir ${previousDataDir} \
              --new-datadir "$staging" \
              --old-options '-c archive_mode=off' \
              --socketdir "$RUNTIME_DIRECTORY" \
              --copy-file-range
            # StateDirectory may have left an empty one behind
            rmdir ${pg.dataDir} 2>/dev/null || true
            mv -T "$staging" ${pg.dataDir}
          '';
        };

        services.pgadmin = {
          enable = true;
          initialEmail = "admin@scottylabs.org";
          initialPasswordFile = config.age.secrets.pgadmin.path;
        };

        scottylabs.backup.sqlite.pgadmin = "/var/lib/pgadmin/pgadmin4.db";

        age.secrets.pgadmin = {
          file = ../../secrets/pgadmin.age;
          owner = "pgadmin";
          mode = "0400";
        };

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 5050 ]; # pgadmin

        services.prometheus.exporters.postgres = {
          enable = true;
          runAsLocalSuperUser = true;
          extraFlags = [ "--no-collector.replication" ];
        };
      };
    };

  scottylabs.observability.dashboards = [
    {
      folder = "infra";
      name = "postgres";
      source = grafana.dashboard {
        title = "Postgres";
        uid = "infra-postgres";
        panels = [
          (grafana.stat {
            title = "Up";
            pos = {
              h = 6;
              w = 6;
              x = 0;
              y = 0;
            };
            targets = [
              (grafana.target {
                expr = "pg_up";
                legend = "{{instance}}";
              })
            ];
            defaults = {
              unit = "short";
              mappings = [
                {
                  type = "value";
                  options = {
                    "0" = {
                      text = "down";
                      color = "red";
                    };
                    "1" = {
                      text = "up";
                      color = "green";
                    };
                  };
                }
              ];
            };
          })
          (grafana.timeseries {
            title = "Active connections by database";
            pos = {
              h = 8;
              w = 18;
              x = 6;
              y = 0;
            };
            targets = [
              (grafana.target {
                expr = "sum by (instance, datname) (pg_stat_database_numbackends)";
                legend = "{{instance}} / {{datname}}";
              })
            ];
            defaults.unit = "short";
          })
          (grafana.timeseries {
            title = "Transactions/sec (commit + rollback)";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 8;
            };
            targets = [
              (grafana.target {
                expr = "sum by (datname) (rate(pg_stat_database_xact_commit[5m]))";
                legend = "commit {{datname}}";
              })
              (grafana.target {
                expr = "sum by (datname) (rate(pg_stat_database_xact_rollback[5m]))";
                legend = "rollback {{datname}}";
              })
            ];
            defaults.unit = "ops";
          })
          (grafana.timeseries {
            title = "Cache hit ratio";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 8;
            };
            targets = [
              (grafana.target {
                expr = "sum by (datname) (rate(pg_stat_database_blks_hit[5m])) / (sum by (datname) (rate(pg_stat_database_blks_hit[5m])) + sum by (datname) (rate(pg_stat_database_blks_read[5m])))";
                legend = "{{datname}}";
              })
            ];
            defaults = {
              unit = "percentunit";
              min = 0;
              max = 1;
            };
          })
          (grafana.timeseries {
            title = "Database sizes";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 16;
            };
            targets = [
              (grafana.target {
                expr = "pg_database_size_bytes";
                legend = "{{instance}} / {{datname}}";
              })
            ];
            defaults.unit = "bytes";
          })
          (grafana.timeseries {
            title = "Deadlocks + conflicts";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 16;
            };
            targets = [
              (grafana.target {
                expr = "sum by (datname) (rate(pg_stat_database_deadlocks[5m]))";
                legend = "deadlocks {{datname}}";
              })
              (grafana.target {
                expr = "sum by (datname) (rate(pg_stat_database_conflicts[5m]))";
                legend = "conflicts {{datname}}";
              })
            ];
            defaults.unit = "ops";
          })
        ];
      };
    }
  ];

  scottylabs.observability.alerts.rules = [
    {
      name = "postgres-down";
      source = grafana.upAlert {
        name = "postgres";
        job = "postgres";
        uid = "infra-postgres-down";
        title = "Postgres down";
        severity = "critical";
        summary = "PostgreSQL is not responding to Prometheus scrapes";
        duration = "2m";
      };
    }
  ];
}
