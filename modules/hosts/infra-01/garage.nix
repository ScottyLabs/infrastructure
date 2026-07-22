{ config, ... }:
{
  flake.modules.nixos.infra-01-garage =
    { config, ... }:

    {
      scottylabs.garage = {
        enable = true;
        environmentFile = config.age.secrets.garage.path;
        webadmin = {
          enable = true;
          domain = "garage.scottylabs.org";
        };
      };

      systemd.services.caddy.vault.infraSecrets = {
        oidc = {
          path = "garage-webadmin-oidc";
          key = "CLIENT_SECRET";
        };
        jwt = {
          path = "garage-webadmin-jwt";
          key = "SECRET";
        };
      };

      age.secrets.garage = {
        file = ../../../secrets/infra-01/garage.age;
        mode = "0400";
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
                host = "infra-01";
                type = "CNAME";
                comment = "Garage S3-compatible object storage";
              };
              assets = {
                host = "infra-01";
                type = "CNAME";
                comment = "Garage public-read website endpoint for the scottylabs-assets bucket";
              };
              cdn = {
                host = "infra-01";
                type = "CNAME";
                comment = "Garage public-read CDN";
              };
              docs = {
                host = "infra-01";
                type = "CNAME";
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
            };
          }
        ];
      };
    };
}
