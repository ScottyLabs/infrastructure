{
  flake.modules.nixos.infra-01-observability =
    { inputs, lib, ... }:

    let
      hostnames = builtins.attrNames inputs.self.nixosConfigurations;

      nodeTargets = map (h: "${h}:9100") hostnames;
      systemdTargets = map (h: "${h}:9558") hostnames;
    in
    {
      systemd.services.grafana.vault.infraSecrets = {
        oidc = {
          path = "grafana-oidc";
          key = "CLIENT_SECRET";
        };
        secretkey = {
          path = "grafana-secret-key";
          key = "SECRET_KEY";
        };
      };

      systemd.services.loki.vault.environmentTemplate = ''
        {{ with secret "secret/data/infra/loki-s3" }}{{ .Data.data.ENV }}{{ end }}
      '';

      systemd.services.tempo.vault.environmentTemplate = ''
        {{ with secret "secret/data/infra/tempo-s3" }}{{ .Data.data.ENV }}{{ end }}
      '';

      systemd.services.prometheus.vault.infraSecrets = {
        uptimekuma = {
          path = "uptime-kuma-metrics";
          key = "API_KEY";
        };
        litellmmetrics = {
          path = "litellm-master-key";
          key = "MASTER_KEY";
        };
      };

      # The observability flake reads these via $__file{/run/secrets/<name>}
      services.vault.agents.files.settings = {
        vault.address = "https://secrets.scottylabs.org";
        auto_auth.method = [
          {
            type = "approle";
            config = {
              role_id_file_path = "/run/agenix/bao-role-id";
              secret_id_file_path = "/run/agenix/bao-secret-id";
              remove_secret_id_file_after_reading = false;
            };
          }
        ];
        template = lib.mkForce [
          {
            contents = ''{{ with secret "secret/data/infra/discord-webhook-alerts" }}{{ .Data.data.URL }}{{ end }}'';
            destination = "/run/secrets/discord-webhook-alerts";
            perms = "0400";
            user = "grafana";
          }
          {
            contents = ''{{ with secret "secret/data/infra/slack-webhook-alerts" }}{{ .Data.data.URL }}{{ end }}'';
            destination = "/run/secrets/slack-webhook-alerts";
            perms = "0400";
            user = "grafana";
          }
        ];
      };

      scottylabs.prometheus = {
        enable = true;
        scrapeJobs = [
          {
            job_name = "prometheus";
            static_configs = [ { targets = [ "localhost:9090" ]; } ];
          }
          {
            job_name = "node";
            static_configs = [ { targets = nodeTargets; } ];
          }
          {
            job_name = "systemd";
            static_configs = [ { targets = systemdTargets; } ];
          }
          {
            job_name = "loki";
            static_configs = [ { targets = [ "localhost:3101" ]; } ];
            metrics_path = "/metrics";
          }
          {
            job_name = "tempo";
            static_configs = [ { targets = [ "localhost:3200" ]; } ];
          }
          {
            job_name = "grafana";
            static_configs = [ { targets = [ "localhost:3000" ]; } ];
          }
          {
            job_name = "otel-collector";
            static_configs = [ { targets = [ "localhost:8888" ]; } ];
          }
          {
            job_name = "postgres";
            static_configs = [
              {
                targets = [
                  "infra-01:9187"
                  "deploy-01:9187"
                ];
              }
            ];
          }
          {
            job_name = "caddy";
            static_configs = [ { targets = [ "localhost:2019" ]; } ];
          }
          {
            job_name = "openbao";
            static_configs = [ { targets = [ "localhost:8200" ]; } ];
            metrics_path = "/v1/sys/metrics";
            params.format = [ "prometheus" ];
          }
          {
            job_name = "garage";
            static_configs = [ { targets = [ "localhost:3903" ]; } ];
          }
          {
            job_name = "headscale";
            static_configs = [ { targets = [ "localhost:9091" ]; } ];
          }
          {
            job_name = "keycloak";
            static_configs = [ { targets = [ "localhost:9092" ]; } ];
          }
          {
            job_name = "keycloak-events";
            static_configs = [ { targets = [ "localhost:8080" ]; } ];
            metrics_path = "/realms/master/metrics";
          }
          {
            job_name = "kennel";
            static_configs = [ { targets = [ "deploy-01:3001" ]; } ];
          }
          {
            job_name = "cadvisor";
            static_configs = [
              {
                targets = [
                  "infra-01:4194"
                  "deploy-01:4194"
                  "signage-01:4194"
                  "snoopy:4194"
                ];
              }
            ];
          }
          {
            job_name = "uptime-kuma";
            static_configs = [ { targets = [ "localhost:3001" ]; } ];
            metrics_path = "/metrics";
            basic_auth = {
              username = "prometheus";
              password_file = "/run/credentials/prometheus.service/uptimekuma";
            };
          }
          {
            job_name = "litellm";
            static_configs = [ { targets = [ "localhost:4000" ]; } ];
            metrics_path = "/metrics/";
            authorization.credentials_file = "/run/credentials/prometheus.service/litellmmetrics";
          }
          {
            job_name = "atlantis";
            static_configs = [ { targets = [ "localhost:4141" ]; } ];
            metrics_path = "/metrics";
          }
          {
            job_name = "synapse";
            static_configs = [ { targets = [ "localhost:9008" ]; } ];
            metrics_path = "/_synapse/metrics";
          }
        ];
      };

      scottylabs.loki.enable = true;
      scottylabs.tempo.enable = true;
      scottylabs.grafana.enable = true;
    };
}
