{ config, ... }:

let
  hosts = {
    infra-01         = "infra-01";
    deploy-01        = "deploy-01";
    snoopy           = "snoopy";
    bus-sign-display = "bus-sign-display";
  };

  nodeTargets    = map (h: "${h}:9100") (builtins.attrValues hosts);
  systemdTargets = map (h: "${h}:9558") (builtins.attrValues hosts);
in
{
  scottylabs.bao-agent.infraSecrets = {
    grafana-oidc = {
      path = "grafana-oidc";
      key  = "CLIENT_SECRET";
      user = "grafana";
    };
    grafana-secret-key = {
      path = "grafana-secret-key";
      key  = "SECRET_KEY";
      user = "grafana";
    };
    loki-s3 = {
      path = "loki-s3";
      key  = "ENV";
      user = "loki";
    };
    tempo-s3 = {
      path = "tempo-s3";
      key  = "ENV";
      user = "tempo";
    };
  };

  scottylabs.prometheus = {
    enable = true;
    scrapeJobs = [
      {
        job_name = "prometheus";
        static_configs = [{ targets = [ "localhost:9090" ]; }];
      }
      {
        job_name = "node";
        static_configs = [{ targets = nodeTargets; }];
      }
      {
        job_name = "systemd";
        static_configs = [{ targets = systemdTargets; }];
      }
      {
        job_name = "loki";
        static_configs = [{ targets = [ "localhost:3101" ]; }];
        metrics_path = "/metrics";
      }
      {
        job_name = "tempo";
        static_configs = [{ targets = [ "localhost:3200" ]; }];
      }
      {
        job_name = "grafana";
        static_configs = [{ targets = [ "localhost:3000" ]; }];
      }
      {
        job_name = "otel-collector";
        static_configs = [{ targets = [ "localhost:8888" ]; }];
      }
      {
        job_name = "postgres";
        static_configs = [{ targets = [ "infra-01:9187" "deploy-01:9187" ]; }];
      }
      {
        job_name = "caddy";
        static_configs = [{ targets = [ "localhost:2019" ]; }];
      }
      {
        job_name = "openbao";
        static_configs = [{ targets = [ "localhost:8200" ]; }];
        metrics_path = "/v1/sys/metrics";
        params.format = [ "prometheus" ];
      }
      {
        job_name = "garage";
        static_configs = [{ targets = [ "localhost:3903" ]; }];
      }
      {
        job_name = "headscale";
        static_configs = [{ targets = [ "localhost:9091" ]; }];
      }
      {
        job_name = "keycloak";
        static_configs = [{ targets = [ "localhost:9092" ]; }];
      }
      {
        job_name = "keycloak-events";
        static_configs = [{ targets = [ "localhost:8080" ]; }];
        metrics_path = "/realms/master/metrics";
      }
      {
        job_name = "kennel";
        static_configs = [{ targets = [ "deploy-01:3001" ]; }];
      }
      {
        job_name = "cadvisor";
        static_configs = [{
          targets = [ "infra-01:4194" "deploy-01:4194" "snoopy:4194" ];
        }];
      }
    ];
  };

  scottylabs.loki = {
    enable = true;
    s3CredentialsFile = "/run/secrets/loki-s3";
  };

  scottylabs.tempo = {
    enable = true;
    s3CredentialsFile = "/run/secrets/tempo-s3";
  };

  scottylabs.grafana.enable = true;

  systemd.services.loki = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };

  systemd.services.tempo = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };

  systemd.services.grafana = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };
}
