{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.tempo;
in
{
  options.scottylabs.tempo = {
    enable = lib.mkEnableOption "Tempo distributed tracing backend";

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3200;
    };

    otlpGrpcPort = lib.mkOption {
      type = lib.types.port;
      default = 4327;
    };

    otlpHttpPort = lib.mkOption {
      type = lib.types.port;
      default = 4328;
    };

    bucket = lib.mkOption {
      type = lib.types.str;
      default = "tempo-traces";
    };

    s3Endpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://s3.scottylabs.org";
    };

    s3CredentialsFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to env file containing TEMPO_S3_ACCESS_KEY_ID and
        TEMPO_S3_SECRET_ACCESS_KEY. Templated by bao-agent.
      '';
    };

    retentionPeriod = lib.mkOption {
      type = lib.types.str;
      default = "336h";
      description = "Block retention. 336h = 14d.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tempo = {
      enable = true;
      settings = {
        server = {
          http_listen_port = cfg.httpPort;
          grpc_listen_port = 9096;
        };

        distributor.receivers.otlp.protocols = {
          grpc.endpoint = "0.0.0.0:${toString cfg.otlpGrpcPort}";
          http.endpoint = "0.0.0.0:${toString cfg.otlpHttpPort}";
        };

        storage.trace = {
          backend = "s3";
          s3 = {
            endpoint = lib.removePrefix "https://" cfg.s3Endpoint;
            bucket = cfg.bucket;
            forcepathstyle = true;
            insecure = false;
            access_key = "\${TEMPO_S3_ACCESS_KEY}";
            secret_key = "\${TEMPO_S3_SECRET_KEY}";
          };
          wal.path = "/var/lib/tempo/wal";
          local.path = "/var/lib/tempo/blocks";

          compaction = {
            block_retention = cfg.retentionPeriod;
            compacted_block_retention = "1h";
          };
        };

        usage_report.reporting_enabled = false;
      };

      extraFlags = [ "-config.expand-env=true" ];
    };

    users.users.tempo = {
      isSystemUser = true;
      group = "tempo";
    };
    users.groups.tempo = { };

    systemd.services.tempo.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "tempo";
      Group = lib.mkForce "tempo";
      EnvironmentFile = cfg.s3CredentialsFile;
    };
  };
}
