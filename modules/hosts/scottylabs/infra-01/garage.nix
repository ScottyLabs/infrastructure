{ config, grafana, ... }:
{
  flake.modules.nixos.scottylabs-infra-01-garage =
    { config, ... }:

    {
      scottylabs.garage = {
        enable = true;
        environmentFile = config.age.secrets.garage.path;
      };

      scottylabs.caddy.sso.sites.garage-webadmin.domain = "garage.scottylabs.org";
      services.caddy.virtualHosts."garage.scottylabs.org".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString config.scottylabs.garage.adminPort}
      '';

      age.secrets.garage = {
        file = ../../../../secrets/scottylabs/infra-01/garage.age;
        mode = "0400";
      };

      scottylabs.backup.garage = {
        scottylabs-docs.enable = false;
        sccache.enable = false;
      };

      # Public read-only vhost for the scottylabs-assets bucket, Host rewritten to its globalAlias
      services.caddy.virtualHosts."assets.scottylabs.org".extraConfig = ''
        reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
          header_up Host scottylabs-assets
        }
      '';

      # Public read-only CDN for per-project buckets, /<repo>/<key> serves <key> from cdn-<repo>
      services.caddy.virtualHosts."cdn.scottylabs.org".extraConfig = ''
        @cdn path_regexp seg ^/([^/]+)/(.*)$
        rewrite @cdn /{re.seg.2}
        reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
          header_up Host cdn-{re.seg.1}
        }
      '';

      # Documentation hub static site served from Garage
      # Accept text/markdown negotiation serves pre-built .md files
      services.caddy.virtualHosts."docs.scottylabs.org".extraConfig = ''
        # Accept Markdown: https://acceptmarkdown.com/recipes/caddy
        @markdown header Accept *text/markdown*

        @markdownHtml {
          header Accept *text/markdown*
          path_regexp html ^(?P<stem>.+)\.html$
        }
        rewrite @markdownHtml /{re.html.stem}.md

        @markdownIndex {
          header Accept *text/markdown*
          path_regexp /$
          not path_regexp \.md$
        }
        rewrite @markdownIndex {path}index.md

        @markdownNoSlash {
          header Accept *text/markdown*
          not path_regexp \.md$
          not path_regexp \.html$
          not path_regexp /$
        }
        rewrite @markdownNoSlash {path}/index.md

        header @markdown >Content-Type "text/markdown; charset=utf-8"
        header Vary "Accept"

        reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
          header_up Host scottylabs-docs
        }
      '';
    };

  scottylabs.observability.dashboards = [
    {
      folder = "infra";
      name = "garage";
      source = grafana.dashboard {
        title = "Garage / S3";
        uid = "infra-garage";
        panels = [
          (grafana.stat {
            title = "Cluster healthy";
            pos = {
              h = 6;
              w = 6;
              x = 0;
              y = 0;
            };
            targets = [ (grafana.target { expr = "garage_cluster_healthy"; }) ];
            defaults.mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "DEGRADED";
                    color = "red";
                  };
                  "1" = {
                    text = "healthy";
                    color = "green";
                  };
                };
              }
            ];
          })
          (grafana.stat {
            title = "Connected nodes";
            pos = {
              h = 6;
              w = 6;
              x = 6;
              y = 0;
            };
            targets = [ (grafana.target { expr = "garage_cluster_connected_nodes"; }) ];
            defaults.unit = "short";
          })
          (grafana.timeseries {
            title = "API request rate by operation";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 0;
            };
            targets = [
              (grafana.target {
                expr = "sum by (api_endpoint) (rate(garage_api_s3_requests_total[5m]))";
                legend = "{{api_endpoint}}";
              })
            ];
            defaults.unit = "ops";
          })
          (grafana.timeseries {
            title = "API error rate";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 6;
            };
            targets = [
              (grafana.target {
                expr = "sum by (api_endpoint) (rate(garage_api_s3_errors_total[5m]))";
                legend = "{{api_endpoint}}";
              })
            ];
            defaults.unit = "ops";
          })
          (grafana.timeseries {
            title = "API latency (p95)";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 8;
            };
            targets = [
              (grafana.target {
                expr = "histogram_quantile(0.95, sum by (le, api_endpoint) (rate(garage_api_s3_request_duration_bucket[5m])))";
                legend = "{{api_endpoint}}";
              })
            ];
            defaults.unit = "s";
          })
          (grafana.timeseries {
            title = "Local disk used vs available";
            pos = {
              h = 8;
              w = 12;
              x = 0;
              y = 14;
            };
            targets = [
              (grafana.target {
                expr = "garage_local_disk_total - garage_local_disk_avail";
                legend = "used";
              })
              (grafana.target {
                expr = "garage_local_disk_avail";
                legend = "available";
              })
            ];
            defaults.unit = "bytes";
          })
          (grafana.timeseries {
            title = "Block I/O bytes/sec";
            pos = {
              h = 8;
              w = 12;
              x = 12;
              y = 16;
            };
            targets = [
              (grafana.target {
                expr = "rate(garage_block_bytes_read_total[5m])";
                legend = "read";
              })
              (grafana.target {
                expr = "rate(garage_block_bytes_written_total[5m])";
                legend = "write";
              })
            ];
            defaults.unit = "Bps";
          })
          (grafana.timeseries {
            title = "Block resync queue length";
            pos = {
              h = 8;
              w = 24;
              x = 0;
              y = 22;
            };
            targets = [
              (grafana.target {
                expr = "garage_block_resync_queue_length";
                legend = "queued";
              })
            ];
            defaults.unit = "short";
          })
        ];
      };
    }
  ];

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.garage = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          # Don't use S3 state backend for S3 state itself
          {
            dns = {
              s3 = {
                name = "s3";
                tunnel = "scottylabs-infra-01";
                comment = "Garage S3-compatible object storage";
              };
              assets = {
                name = "assets";
                tunnel = "scottylabs-infra-01";
                comment = "Garage public-read website endpoint for the scottylabs-assets bucket";
              };
              cdn = {
                name = "cdn";
                tunnel = "scottylabs-infra-01";
                comment = "Garage public-read CDN";
              };
              docs = {
                name = "docs";
                tunnel = "scottylabs-infra-01";
                comment = "ScottyLabs documentation hub (Garage scottylabs-docs bucket)";
              };
            };
            resource.garage_bucket = {
              tofu_state.global_alias = "tofu-state";
              # Org-wide static assets that outlive any single kennel deployment
              scottylabs_assets = {
                global_alias = "scottylabs-assets";
                website_enabled = true;
                website_index_document = "index.html";
              };
              # Documentation hub, uploaded by documentation CI
              scottylabs_docs = {
                global_alias = "scottylabs-docs";
                website_enabled = true;
                website_index_document = "index.html";
              };
              # Shared sccache compilation cache for Rust builds
              sccache.global_alias = "sccache";
            };

            resource.garage_key = {
              governance.name = "governance-tofu";
              infra_tofu_state.name = "infra-tofu-state";
              scottylabs_assets_writer.name = "scottylabs-assets-writer";
              scottylabs_docs_writer.name = "scottylabs-docs-writer";
              sccache.name = "sccache";
              sccache_reader.name = "sccache-reader";
            };

            resource.garage_bucket_permission = {
              governance_tofu_state = {
                access_key_id = "\${garage_key.governance.id}";
                bucket_id = "\${garage_bucket.tofu_state.id}";
                read = true;
                write = true;
                owner = true;
              };
              infra_tofu_state = {
                access_key_id = "\${garage_key.infra_tofu_state.id}";
                bucket_id = "\${garage_bucket.tofu_state.id}";
                read = true;
                write = true;
                owner = true;
              };
              scottylabs_assets_writer = {
                access_key_id = "\${garage_key.scottylabs_assets_writer.id}";
                bucket_id = "\${garage_bucket.scottylabs_assets.id}";
                read = true;
                write = true;
                owner = true;
              };
              scottylabs_docs_writer = {
                access_key_id = "\${garage_key.scottylabs_docs_writer.id}";
                bucket_id = "\${garage_bucket.scottylabs_docs.id}";
                read = true;
                write = true;
                owner = true;
              };
              sccache = {
                access_key_id = "\${garage_key.sccache.id}";
                bucket_id = "\${garage_bucket.sccache.id}";
                read = true;
                write = true;
                owner = false;
              };
              sccache_reader = {
                access_key_id = "\${garage_key.sccache_reader.id}";
                bucket_id = "\${garage_bucket.sccache.id}";
                read = true;
                write = false;
                owner = false;
              };
            };

            resource.vault_kv_secret_v2.sccache_s3 = {
              mount = "secret";
              name = "shared/sccache";
              data_json = "\${jsonencode({ AWS_ACCESS_KEY_ID = garage_key.sccache.id, AWS_SECRET_ACCESS_KEY = garage_key.sccache.secret_access_key })}";
            };

            output = {
              governance_access_key_id = {
                value = "\${garage_key.governance.id}";
                sensitive = true;
              };
              governance_secret_access_key = {
                value = "\${garage_key.governance.secret_access_key}";
                sensitive = true;
              };
              infra_tofu_state_access_key_id = {
                value = "\${garage_key.infra_tofu_state.id}";
                sensitive = true;
              };
              infra_tofu_state_secret_access_key = {
                value = "\${garage_key.infra_tofu_state.secret_access_key}";
                sensitive = true;
              };
              scottylabs_assets_writer_access_key_id = {
                value = "\${garage_key.scottylabs_assets_writer.id}";
                sensitive = true;
              };
              scottylabs_assets_writer_secret_access_key = {
                value = "\${garage_key.scottylabs_assets_writer.secret_access_key}";
                sensitive = true;
              };
              scottylabs_docs_writer_access_key_id = {
                value = "\${garage_key.scottylabs_docs_writer.id}";
                sensitive = true;
              };
              scottylabs_docs_writer_secret_access_key = {
                value = "\${garage_key.scottylabs_docs_writer.secret_access_key}";
                sensitive = true;
              };
              sccache_reader_access_key_id = {
                value = "\${garage_key.sccache_reader.id}";
                sensitive = true;
              };
              sccache_reader_secret_access_key = {
                value = "\${garage_key.sccache_reader.secret_access_key}";
                sensitive = true;
              };
            };
          }
        ];
      };

      terranix.terranixConfigurations.garage-webadmin = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/garage-webadmin.tfstate";
            dns.garage = {
              name = "garage";
              tunnel = "scottylabs-infra-01";
              comment = "Garage web admin UI fronted by caddy with Keycloak OIDC";
            };
            resource.keycloak_openid_client.garage_webadmin = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "garage-webadmin";
              name = "Garage Web Admin";
              enabled = true;
              access_type = "CONFIDENTIAL";
              standard_flow_enabled = true;
              direct_access_grants_enabled = false;
              valid_redirect_uris = [
                "https://garage.scottylabs.org/auth/oauth2/scottylabs/authorization-code-callback"
              ];
            };

            resource.keycloak_openid_group_membership_protocol_mapper.garage_webadmin_groups = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "\${keycloak_openid_client.garage_webadmin.id}";
              name = "groups";
              claim_name = "groups";
              full_path = true;
            };

            resource.random_password.garage_webadmin_jwt = {
              length = 64;
              special = false;
            };

            resource.vault_kv_secret_v2 = {
              garage_webadmin_oidc = {
                mount = "secret";
                name = "infra/garage-webadmin-oidc";
                data_json = "\${jsonencode({ CLIENT_SECRET = keycloak_openid_client.garage_webadmin.client_secret })}";
              };
              garage_webadmin_jwt = {
                mount = "secret";
                name = "infra/garage-webadmin-jwt";
                data_json = "\${jsonencode({ SECRET = random_password.garage_webadmin_jwt.result })}";
              };
            };

            output.garage_webadmin_client_secret = {
              value = "\${keycloak_openid_client.garage_webadmin.client_secret}";
              sensitive = true;
            };
          }
        ];
      };
    };
}
