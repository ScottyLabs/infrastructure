{ config, grafana, ... }:
{
  flake.modules.nixos.infra-01-openbao = {
    services.openbao = {
      enable = true;
      settings = {
        ui = true;
        listener.default = {
          type = "tcp";
          address = "127.0.0.1:8200";
          tls_disable = true;
          telemetry.unauthenticated_metrics_access = true;
        };

        storage.postgresql.connection_url = "postgresql:///openbao?host=/run/postgresql&user=openbao";

        log_level = "debug";

        cluster_name = "default";
        cluster_addr = "http://127.0.0.1:8201";

        api_addr = "https://secrets.scottylabs.org";

        telemetry = {
          prometheus_retention_time = "24h";
          disable_hostname = true;
        };
      };
    };

    services.caddy.virtualHosts."secrets.scottylabs.org".extraConfig = ''
      reverse_proxy 127.0.0.1:8200
    '';

    scottylabs.postgresql.databases = [ "openbao" ];
  };

  scottylabs.observability = {
    dashboards = [
      {
        folder = "infra";
        name = "openbao";
        source = grafana.dashboard {
          title = "OpenBao";
          uid = "infra-openbao";
          panels = [
            (grafana.stat {
              title = "Sealed";
              pos = {
                h = 6;
                w = 6;
                x = 0;
                y = 0;
              };
              targets = [ (grafana.target { expr = "vault_core_unsealed"; }) ];
              defaults.mappings = [
                {
                  type = "value";
                  options = {
                    "0" = {
                      text = "SEALED";
                      color = "red";
                    };
                    "1" = {
                      text = "unsealed";
                      color = "green";
                    };
                  };
                }
              ];
            })
            (grafana.stat {
              title = "Cache hit ratio";
              pos = {
                h = 6;
                w = 6;
                x = 6;
                y = 0;
              };
              targets = [ (grafana.target { expr = "vault_cache_hit / (vault_cache_hit + vault_cache_miss)"; }) ];
              defaults = {
                unit = "percentunit";
                min = 0;
                max = 1;
              };
            })
            (grafana.timeseries {
              title = "Audit log request rate";
              pos = {
                h = 8;
                w = 12;
                x = 12;
                y = 0;
              };
              targets = [
                (grafana.target {
                  expr = "rate(vault_audit_log_request_count[5m])";
                  legend = "requests";
                })
                (grafana.target {
                  expr = "rate(vault_audit_log_response_count[5m])";
                  legend = "responses";
                })
              ];
              defaults.unit = "ops";
            })
            (grafana.stat {
              title = "Audit log failures";
              pos = {
                h = 6;
                w = 6;
                x = 0;
                y = 6;
              };
              targets = [
                (grafana.target { expr = "vault_audit_log_request_failure + vault_audit_log_response_failure"; })
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
                      color = "red";
                      value = 1;
                    }
                  ];
                };
              };
            })
            (grafana.timeseries {
              title = "Barrier operation rates";
              pos = {
                h = 8;
                w = 12;
                x = 6;
                y = 6;
              };
              targets = [
                (grafana.target {
                  expr = "rate(vault_barrier_get_count[5m])";
                  legend = "get";
                })
                (grafana.target {
                  expr = "rate(vault_barrier_put_count[5m])";
                  legend = "put";
                })
                (grafana.target {
                  expr = "rate(vault_barrier_list_count[5m])";
                  legend = "list";
                })
                (grafana.target {
                  expr = "rate(vault_barrier_delete_count[5m])";
                  legend = "delete";
                })
              ];
              defaults = {
                unit = "ops";
                custom = {
                  stacking = {
                    mode = "normal";
                  };
                };
              };
            })
            (grafana.timeseries {
              title = "Barrier latency (p99)";
              pos = {
                h = 8;
                w = 12;
                x = 0;
                y = 14;
              };
              targets = [
                (grafana.target {
                  expr = "vault_barrier_get{quantile=\"0.99\"}";
                  legend = "get";
                })
                (grafana.target {
                  expr = "vault_barrier_put{quantile=\"0.99\"}";
                  legend = "put";
                })
                (grafana.target {
                  expr = "vault_barrier_list{quantile=\"0.99\"}";
                  legend = "list";
                })
              ];
              defaults.unit = "s";
            })
            (grafana.timeseries {
              title = "Runtime memory + goroutines";
              pos = {
                h = 8;
                w = 12;
                x = 12;
                y = 14;
              };
              targets = [
                (grafana.target {
                  expr = "vault_runtime_alloc_bytes";
                  legend = "alloc bytes";
                })
                (grafana.target {
                  expr = "vault_runtime_sys_bytes";
                  legend = "sys bytes";
                })
                (grafana.target {
                  expr = "vault_runtime_num_goroutines * 1048576";
                  legend = "goroutines (x1MiB scale)";
                })
              ];
              defaults.unit = "bytes";
            })
            (grafana.timeseries {
              title = "GC pauses";
              pos = {
                h = 8;
                w = 24;
                x = 0;
                y = 22;
              };
              targets = [
                (grafana.target {
                  expr = "rate(vault_runtime_gc_pause_ns_sum[5m]) / 1e9";
                  legend = "GC pause s/s";
                })
              ];
              defaults.unit = "s";
            })
          ];
        };
      }
    ];
    alerts.rules = [
      {
        name = "openbao-sealed";
        source = grafana.promAlert {
          name = "openbao";
          uid = "infra-openbao-sealed";
          title = "OpenBao sealed";
          expr = "vault_core_unsealed == bool 0";
          severity = "critical";
          summary = "OpenBao is sealed; bao-agent will lose its token within ~1h and dependent services will start failing";
        };
      }
    ];
  };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.openbao = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/openbao.tfstate";
            dns.secrets = {
              host = "infra-01";
              type = "CNAME";
              comment = "OpenBao";
            };
            locals.hosts = ''''${toset(["infra-01", "deploy-01", "snoopy", "signage-01"])}'';

            resource.vault_mount.kv = {
              path = "secret";
              type = "kv";
              options.version = "2";
              description = "KV v2 secrets engine";
            };

            resource.vault_jwt_auth_backend.oidc = {
              path = "oidc";
              type = "oidc";
              oidc_discovery_url = "https://idp.scottylabs.org/realms/scottylabs";
              oidc_client_id = "openbao";
              oidc_client_secret = "\${keycloak_openid_client.openbao.client_secret}";
              default_role = "default";
              # Makes OIDC the default option on the login page
              tune = [
                {
                  listing_visibility = "unauth";
                  max_lease_ttl = "8760h";
                  default_lease_ttl = "768h";
                  token_type = "default-service";
                  audit_non_hmac_request_keys = [ ];
                  audit_non_hmac_response_keys = [ ];
                  allowed_response_headers = [ ];
                  passthrough_request_headers = [ ];
                }
              ];
            };

            resource.vault_jwt_auth_backend_role.default = {
              backend = "\${vault_jwt_auth_backend.oidc.path}";
              role_name = "default";
              role_type = "oidc";
              bound_audiences = [ "openbao" ];
              user_claim = "preferred_username";
              groups_claim = "groups";
              token_policies = [ "default" ];
              # 90 days, renews on each shell entry
              token_period = 7776000;
              allowed_redirect_uris = [
                "https://secrets.scottylabs.org/v1/auth/oidc/callback"
                "https://secrets.scottylabs.org/ui/vault/auth/oidc/oidc/callback"
                "http://localhost:8250/oidc/callback"
              ];
            };

            # Machine authentication for NixOS hosts
            resource.vault_auth_backend.approle = {
              type = "approle";
              path = "approle";
            };

            resource.vault_approle_auth_backend_role.host = {
              for_each = "\${local.hosts}";
              backend = "\${vault_auth_backend.approle.path}";
              role_name = "\${each.value}";
              token_policies = [ "\${vault_policy.infra.name}" ];
              token_ttl = 3600;
              token_max_ttl = 86400;
              secret_id_ttl = 0;
            };

            # Infrastructure secrets all hosts can read
            resource.vault_policy.infra = {
              name = "infra";
              policy = ''
                path "secret/data/infra/*" {
                  capabilities = ["read"]
                }
                path "secret/metadata/infra/*" {
                  capabilities = ["list", "read"]
                }
              '';
            };

            resource.keycloak_openid_client.openbao = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "openbao";
              name = "OpenBao";
              enabled = true;
              access_type = "CONFIDENTIAL";
              standard_flow_enabled = true;
              direct_access_grants_enabled = false;
              valid_redirect_uris = [
                "https://secrets.scottylabs.org/ui/vault/auth/oidc/oidc/callback"
                "https://secrets.scottylabs.org/v1/auth/oidc/*"
                "http://localhost:8250/oidc/callback"
              ];
            };

            # Groups mapper to send full paths in token
            resource.keycloak_openid_group_membership_protocol_mapper.openbao_groups = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "\${keycloak_openid_client.openbao.id}";
              name = "groups";
              claim_name = "groups";
              full_path = true;
            };

            output.approle_role_ids.value = "\${{ for k, v in vault_approle_auth_backend_role.host : k => v.role_id }}";
          }
        ];
      };
    };
}
