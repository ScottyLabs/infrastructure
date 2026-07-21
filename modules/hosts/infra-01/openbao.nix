{ config, ... }:
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
            variable.oidc_client_secret = {
              description = "OIDC client secret from Keycloak";
              sensitive = true;
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
              oidc_client_secret = "\${var.oidc_client_secret}";
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

            data.keycloak_openid_client.openbao = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "openbao";
            };

            # Groups mapper to send full paths in token
            resource.keycloak_openid_group_membership_protocol_mapper.openbao_groups = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "\${data.keycloak_openid_client.openbao.id}";
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
