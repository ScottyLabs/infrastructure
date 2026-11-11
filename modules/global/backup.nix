{
  flake.modules.nixos.backup =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.backup;
      inherit (config.scottylabs) organization;
      inherit (config.networking) hostName;

      account = import ../../data/cloudflare-account.nix;
      endpoint = "${account}.r2.cloudflarestorage.com";
      # Provisioned by the cloudflare-tokens terranix configuration
      credentials = "secret/data/infra/cloudflare-backups-${organization}-${hostName}";
      credentialsFile = "/run/backup/r2.env";

      postgres = config.services.postgresql.enable;
      valkeyServers = lib.filterAttrs (_: server: server.enable) config.services.redis.servers;
      garage = config.scottylabs.garage.enable or false;

      garageMirror = "/var/lib/backup-garage";

      daily = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };

      resticJob =
        repository: job:
        {
          repository = "s3:https://${endpoint}/${cfg.bucket}/restic/${repository}";
          passwordFile = config.age.secrets.restic.path;
          environmentFile = credentialsFile;
          extraOptions = [ "s3.region=auto" ];
          initialize = true;
          timerConfig = daily;
          pruneOpts = [ "--keep-within ${toString cfg.retention}d" ];
        }
        // job;

      valkeyJobs = lib.concatMapAttrs (name: server: {
        "valkey-${name}" = resticJob "valkey-${name}" {
          command = [
            (lib.getExe' config.services.redis.package "valkey-cli")
            "-s"
            server.unixSocket
            "--rdb"
            "-"
          ];
          extraBackupArgs = [
            "--stdin-filename dump.rdb"
            "--retry-lock 5m"
          ];
          timerConfig.OnCalendar = "*:0/5";
          pruneOpts = [ ];
        };

        # Prune daily since backups happen every 5 minutes
        "valkey-${name}-prune" = resticJob "valkey-${name}" {
          initialize = false;
          pruneOpts = [
            "--retry-lock 5m"
            "--keep-within 2d"
            "--keep-daily ${toString cfg.retention}"
          ];
        };
      }) valkeyServers;

      sqliteJobs = lib.mapAttrs' (
        name: path:
        lib.nameValuePair "sqlite-${name}" (
          resticJob "sqlite-${name}" {
            command = [
              (lib.getExe pkgs.sqlite)
              path
              ".dump"
            ];
            extraBackupArgs = [ "--stdin-filename ${name}.sql" ];
          }
        )
      ) cfg.sqlite;

      pathJobs = lib.mapAttrs (
        name: source:
        resticJob name {
          inherit (source) paths exclude timerConfig;
        }
      ) cfg.paths;

      garageFilters = pkgs.writeText "garage-backup-filters" (
        lib.concatLines (
          lib.concatLists (
            lib.mapAttrsToList (
              bucket: settings:
              if settings.enable then
                map (pattern: "- ${bucket}/${pattern}") settings.exclude
              else
                [ "- ${bucket}/**" ]
            ) cfg.garage
          )
        )
      );

      garageJobs = lib.optionalAttrs garage {
        garage = resticJob "garage" {
          paths = [ garageMirror ];
          # Grant on every run to cover buckets that governance and kennel create
          backupPrepareCommand = ''
            #!${pkgs.runtimeShell}
            set -eu
            for bucket in $(${lib.getExe config.services.garage.package} json-api ListBuckets | ${lib.getExe pkgs.jq} -r '.[].id'); do
              ${lib.getExe config.services.garage.package} json-api AllowBucketKey "{\"bucketId\": \"$bucket\", \"accessKeyId\": \"$RCLONE_CONFIG_GARAGE_ACCESS_KEY_ID\", \"permissions\": {\"read\": true, \"write\": false, \"owner\": false}}" >/dev/null
            done
            ${lib.getExe pkgs.rclone} sync --fast-list --delete-excluded --filter-from ${garageFilters} garage: ${garageMirror}
          '';
        };
      };

      resticJobs = valkeyJobs // sqliteJobs // pathJobs // garageJobs;
    in
    {
      options.scottylabs.backup = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = postgres || resticJobs != { };
          defaultText = lib.literalMD "whether the host runs PostgreSQL, Valkey, or Garage, or registers a SQLite database or paths";
          description = "Offsite backups to Cloudflare R2";
        };

        bucket = lib.mkOption {
          type = lib.types.str;
          default = "${organization}-${hostName}-backups";
          readOnly = true;
          description = "R2 bucket created by the backups terranix configuration";
        };

        retention = lib.mkOption {
          type = lib.types.ints.positive;
          default = 90;
          description = "Days of history every backup keeps";
        };

        sqlite = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "SQLite databases dumped daily (name -> database file)";
        };

        paths = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                paths = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Files and directories to back up";
                };
                exclude = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "restic exclude patterns";
                };
                timerConfig = lib.mkOption {
                  type = lib.types.nullOr (lib.types.attrsOf lib.types.unspecified);
                  default = daily;
                  description = "When to back up, or null when another unit starts restic-backups-<name>";
                };
              };
            }
          );
          default = { };
          description = "Files backed up as is, each to its own restic repository";
        };

        garage = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to back up the bucket";
                };
                exclude = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "rclone exclude patterns";
                };
              };
            }
          );
          default = { };
          description = "Overrides for Garage buckets, all of which are backed up by default (global alias -> settings)";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            systemd.tmpfiles.rules = [ "d /run/backup 0700 root root -" ];

            services.vault.agents.default.settings.template = [
              {
                destination = credentialsFile;
                perms = "0400";
                contents = ''
                  {{ with secret "${credentials}" }}AWS_ACCESS_KEY_ID={{ .Data.data.ACCESS_KEY_ID }}
                  AWS_SECRET_ACCESS_KEY={{ .Data.data.SECRET_ACCESS_KEY }}{{ end }}
                '';
              }
            ];
          }

          (lib.mkIf (resticJobs != { }) {
            age.secrets.restic = {
              file = ../../secrets/${organization}/${hostName}/restic.age;
              mode = "0400";
            };

            services.restic.backups = resticJobs;
          })

          (lib.mkIf garage {
            # Keep out of btrbk snapshots
            systemd.tmpfiles.rules = [ "v ${garageMirror} 0700 root root -" ];

            # Import into Garage once with garage key import
            age.secrets.garage-backup = {
              file = ../../secrets/${organization}/${hostName}/garage-backup.age;
              mode = "0400";
            };

            systemd.services.restic-backups-garage = {
              after = [ "garage.service" ];
              environment = {
                RCLONE_CONFIG_GARAGE_TYPE = "s3";
                RCLONE_CONFIG_GARAGE_PROVIDER = "Other";
                RCLONE_CONFIG_GARAGE_ENDPOINT = "http://127.0.0.1:${toString config.scottylabs.garage.s3Port}";
                RCLONE_CONFIG_GARAGE_REGION = config.services.garage.settings.s3_api.s3_region;
                RCLONE_CONFIG_GARAGE_FORCE_PATH_STYLE = "true";
              };
              serviceConfig.EnvironmentFile = lib.mkForce [
                credentialsFile
                config.services.garage.environmentFile
                config.age.secrets.garage-backup.path
              ];
            };
          })

          (lib.mkIf postgres {
            # Keep out of OpenBao, which stores its data in infra-01's PostgreSQL
            age.secrets.pgbackrest = {
              file = ../../secrets/${organization}/${hostName}/pgbackrest.age;
              owner = "postgres";
              group = "postgres";
              mode = "0440";
            };

            services.pgbackrest = {
              enable = true;
              settings = {
                # Return from archive_command before the upload finishes, queueing WAL in the spool
                archive-async = true;
                spool-path = "/var/lib/postgresql/pgbackrest-spool";
                compress-type = "zst";
                process-max = 2;
                # Checkpoint as soon as a backup starts instead of waiting for the next scheduled one
                start-fast = true;
              };

              repos.r2 = {
                type = "s3";
                path = "/pgbackrest";
                s3-bucket = cfg.bucket;
                s3-endpoint = endpoint;
                s3-region = "auto";
                # Encrypt before upload with the passphrase from agenix
                cipher-type = "aes-256-cbc";
                # Expire full backups by age, along with the WAL that only they need
                retention-full-type = "time";
                retention-full = cfg.retention;
                # Pack small files into larger objects to cut R2 requests
                bundle = true;
                # Store only the changed blocks of changed files
                block = true;
              };

              stanzas.default = {
                instances.localhost.socket-path = "/run/postgresql";
                jobs = {
                  full = {
                    schedule = "Sun 04:00";
                    type = "full";
                  };
                  diff = {
                    schedule = "Mon..Sat 04:00";
                    type = "diff";
                  };
                };
              };
            };

            # Switch WAL segments every minute so at most a minute of writes is missing from R2
            services.postgresql.settings.archive_timeout = 60;

            environment.etc = {
              "pgbackrest/conf.d/cipher.conf".source = config.age.secrets.pgbackrest.path;
              "pgbackrest/conf.d/r2.conf".source = "/run/pgbackrest/r2.conf";
            };

            # Avoid vault credentials on postgresql.service, since OpenBao depends on it
            services.vault.agents.default.settings.template = [
              {
                destination = "/run/pgbackrest/r2.conf";
                perms = "0444";
                contents = ''
                  [global]
                  {{ with secret "${credentials}" }}repo1-s3-key={{ .Data.data.ACCESS_KEY_ID }}
                  repo1-s3-key-secret={{ .Data.data.SECRET_ACCESS_KEY }}{{ end }}
                '';
              }
            ];

            systemd.tmpfiles.rules = [
              "d /run/pgbackrest 0750 root postgres -"
              "d /var/lib/postgresql/pgbackrest-spool 0750 postgres postgres -"
            ];
          })
        ]
      );
    };
}
