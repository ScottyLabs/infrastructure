{ config, ... }:
{
  flake.modules.nixos.infra-01-observability =
    { inputs, ... }:

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
        template = [
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

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.observability = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/observability.tfstate";
            dns = {
              grafana = {
                host = "infra-01";
                type = "CNAME";
                comment = "Grafana observability frontend";
              };
              uptime = {
                host = "infra-01";
                type = "CNAME";
                comment = "Uptime Kuma public status page";
              };
            };
            resource.keycloak_openid_client.grafana = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "grafana";
              name = "Grafana";
              enabled = true;
              access_type = "CONFIDENTIAL";
              standard_flow_enabled = true;
              direct_access_grants_enabled = false;
              valid_redirect_uris = [ "https://grafana.scottylabs.org/login/generic_oauth" ];
            };

            resource.keycloak_openid_group_membership_protocol_mapper.grafana_groups = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "\${keycloak_openid_client.grafana.id}";
              name = "groups";
              claim_name = "groups";
              full_path = true;
            };

            resource.random_password.grafana_secret_key = {
              length = 64;
              special = false;
            };

            resource.vault_kv_secret_v2 = {
              grafana_oidc = {
                mount = "secret";
                name = "infra/grafana-oidc";
                data_json = "\${jsonencode({ CLIENT_SECRET = keycloak_openid_client.grafana.client_secret })}";
              };
              grafana_secret_key = {
                mount = "secret";
                name = "infra/grafana-secret-key";
                data_json = "\${jsonencode({ SECRET_KEY = random_password.grafana_secret_key.result })}";
              };
              loki_s3 = {
                mount = "secret";
                name = "infra/loki-s3";
                data_json = ''''${jsonencode({ ENV = "LOKI_S3_ACCESS_KEY_ID=''${garage_key.loki.id}\nLOKI_S3_SECRET_ACCESS_KEY=''${garage_key.loki.secret_access_key}\n" })}'';
              };
              tempo_s3 = {
                mount = "secret";
                name = "infra/tempo-s3";
                data_json = ''''${jsonencode({ ENV = "TEMPO_S3_ACCESS_KEY=''${garage_key.tempo.id}\nTEMPO_S3_SECRET_KEY=''${garage_key.tempo.secret_access_key}\n" })}'';
              };
            };

            resource.garage_bucket = {
              loki_chunks.global_alias = "loki-chunks";
              tempo_traces.global_alias = "tempo-traces";
            };

            resource.garage_key = {
              loki.name = "loki";
              tempo.name = "tempo";
            };

            resource.garage_bucket_permission = {
              loki = {
                access_key_id = "\${garage_key.loki.id}";
                bucket_id = "\${garage_bucket.loki_chunks.id}";
                read = true;
                write = true;
                owner = false;
              };
              tempo = {
                access_key_id = "\${garage_key.tempo.id}";
                bucket_id = "\${garage_bucket.tempo_traces.id}";
                read = true;
                write = true;
                owner = false;
              };
            };
          }
        ];
      };
    };
}
