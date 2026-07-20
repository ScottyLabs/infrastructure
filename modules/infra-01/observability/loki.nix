{
  flake.modules.nixos.loki =
    {
      config,
      lib,
      ...
    }:

    let
      cfg = config.scottylabs.loki;
    in
    {
      options.scottylabs.loki = {
        enable = lib.mkEnableOption "Loki log aggregator";

        port = lib.mkOption {
          type = lib.types.port;
          default = 3101;
        };

        bucket = lib.mkOption {
          type = lib.types.str;
          default = "loki-chunks";
        };

        s3Endpoint = lib.mkOption {
          type = lib.types.str;
          default = "https://s3.scottylabs.org";
        };

        s3CredentialsFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to env file containing LOKI_S3_ACCESS_KEY_ID and
            LOKI_S3_SECRET_ACCESS_KEY. Templated by bao-agent.
          '';
        };

        retentionPeriod = lib.mkOption {
          type = lib.types.str;
          default = "720h";
          description = "Chunk retention. 720h = 30d.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.loki = {
          enable = true;
          configuration = {
            auth_enabled = false;

            server = {
              http_listen_port = cfg.port;
              grpc_listen_port = 9095;
            };

            common = {
              path_prefix = "/var/lib/loki";
              replication_factor = 1;
              ring.kvstore.store = "inmemory";
            };

            schema_config.configs = [
              {
                from = "2026-01-01";
                store = "tsdb";
                object_store = "s3";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];

            storage_config = {
              tsdb_shipper = {
                active_index_directory = "/var/lib/loki/tsdb-active";
                cache_location = "/var/lib/loki/tsdb-cache";
              };
              aws = {
                endpoint = cfg.s3Endpoint;
                bucketnames = cfg.bucket;
                region = "us-east-1";
                access_key_id = "\${LOKI_S3_ACCESS_KEY_ID}";
                secret_access_key = "\${LOKI_S3_SECRET_ACCESS_KEY}";
                s3forcepathstyle = true;
                insecure = false;
              };
            };

            compactor = {
              working_directory = "/var/lib/loki/compactor";
              retention_enabled = true;
              retention_delete_delay = "2h";
              delete_request_store = "s3";
            };

            limits_config = {
              retention_period = cfg.retentionPeriod;
              reject_old_samples = true;
              reject_old_samples_max_age = "168h";
              ingestion_rate_mb = 16;
              ingestion_burst_size_mb = 32;
              allow_structured_metadata = true;
            };

            analytics.reporting_enabled = false;
          };

          extraFlags = [ "-config.expand-env=true" ];
        };

        systemd.services.loki.serviceConfig.EnvironmentFile = cfg.s3CredentialsFile;
      };
    };
}
