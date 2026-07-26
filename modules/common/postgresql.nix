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
      pgExtensions = {
        pg_uuidv7 = "pg_uuidv7";
        pgvector = "vector";
        postgis = "postgis";
      };
      createExtSql = lib.concatMapStringsSep " " (sql: "CREATE EXTENSION IF NOT EXISTS ${sql};") (
        lib.attrValues pgExtensions
      );
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
          package = pkgs.postgresql_18;
          extensions = ps: map (name: ps.${name}) (lib.attrNames pgExtensions);

          ensureDatabases = cfg.databases;

          ensureUsers = map (name: {
            inherit name;
            ensureDBOwnership = true;
          }) cfg.databases;
        };

        # Seed extensions into template1 and each database
        systemd.services.postgresql-setup.postStart = lib.mkAfter (
          lib.concatMapStringsSep "\n" (db: ''
            psql --port=${toString config.services.postgresql.settings.port} -d ${db} -c '${createExtSql}'
          '') ([ "template1" ] ++ cfg.databases)
        );

        services.pgadmin = {
          enable = true;
          initialEmail = "admin@scottylabs.org";
          initialPasswordFile = config.age.secrets.pgadmin.path;
        };

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
