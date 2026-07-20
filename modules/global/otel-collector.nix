{
  flake.modules.nixos.otel-collector =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.otelCollector;

      collectorConfig = pkgs.writeText "otel-collector.yaml" (
        builtins.toJSON {
          receivers.otlp.protocols = {
            grpc.endpoint = "127.0.0.1:${toString cfg.grpcPort}";
            http.endpoint = "127.0.0.1:${toString cfg.httpPort}";
          };

          processors = {
            memory_limiter = {
              check_interval = "1s";
              limit_percentage = 75;
              spike_limit_percentage = 25;
            };
            batch = { };
          };

          exporters = {
            "otlphttp/tempo" = {
              endpoint = "http://${cfg.upstreamHost}:${toString cfg.tempoOtlpPort}";
              tls.insecure = true;
            };
            "otlphttp/loki" = {
              endpoint = "http://${cfg.upstreamHost}:${toString cfg.lokiPort}/otlp";
              tls.insecure = true;
            };
          };

          service.pipelines = {
            traces = {
              receivers = [ "otlp" ];
              processors = [
                "memory_limiter"
                "batch"
              ];
              exporters = [ "otlphttp/tempo" ];
            };
            logs = {
              receivers = [ "otlp" ];
              processors = [
                "memory_limiter"
                "batch"
              ];
              exporters = [ "otlphttp/loki" ];
            };
          };
        }
      );
    in
    {
      options.scottylabs.otelCollector = {
        enable = lib.mkEnableOption "Per-host OpenTelemetry Collector";

        grpcPort = lib.mkOption {
          type = lib.types.port;
          default = 4317;
        };

        httpPort = lib.mkOption {
          type = lib.types.port;
          default = 4318;
        };

        upstreamHost = lib.mkOption {
          type = lib.types.str;
          default = "infra-01";
          description = "Host running Tempo and Loki, resolved over tailscale MagicDNS.";
        };

        tempoOtlpPort = lib.mkOption {
          type = lib.types.port;
          default = 4328;
        };

        lokiPort = lib.mkOption {
          type = lib.types.port;
          default = 3101;
        };
      };

      config = lib.mkIf cfg.enable {
        services.opentelemetry-collector = {
          enable = true;
          configFile = collectorConfig;
        };
      };
    };
}
