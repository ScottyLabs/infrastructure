{ config, ... }:
{
  flake.modules.nixos.headscale =
    {
      config,
      lib,
      ...
    }:

    let
      cfg = config.scottylabs.tailnet.headscale;

      aclPolicy = builtins.toJSON {
        groups = {
          "group:servers" = [ "servers@" ];
        };

        tagOwners = {
          "tag:server" = [ "group:servers" ];
        };

        acls = [
          {
            action = "accept";
            src = [ "*" ];
            dst = [ "*:*" ];
          }
        ];

        ssh = [
          {
            action = "accept";
            src = [ "autogroup:member" ];
            dst = [ "autogroup:tagged" ];
            users = [
              "autogroup:nonroot"
              "root"
            ];
          }
        ];

        autoApprovers = {
          exitNode = [ "tag:server" ];
          routes = builtins.listToAttrs (
            map (route: {
              name = route;
              value = [ "tag:server" ];
            }) cfg.autoApproveRoutes
          );
        };
      };
    in
    {
      options.scottylabs.tailnet.headscale = {
        enable = lib.mkEnableOption "Headscale coordination server";

        domain = lib.mkOption {
          type = lib.types.str;
          default = "headscale.scottylabs.org";
          description = "Public hostname for the headscale API.";
        };

        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 8085;
        };

        metricsPort = lib.mkOption {
          type = lib.types.port;
          default = 9091;
        };

        baseDomain = lib.mkOption {
          type = lib.types.str;
          default = "tail.scottylabs.org";
          description = "MagicDNS base domain.";
        };

        oidcIssuer = lib.mkOption {
          type = lib.types.str;
          default = "https://idp.scottylabs.org/realms/scottylabs";
        };

        oidcClientSecretFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to Keycloak OIDC client_secret for headscale.";
        };

        allowedGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "/projects/devops" ];
          description = "Keycloak groups that may register nodes via OIDC.";
        };

        autoApproveRoutes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Subnet routes auto-approved for tag:server nodes.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.etc."headscale/acl.json" = {
          text = aclPolicy;
          user = "headscale";
          group = "headscale";
          mode = "0400";
        };

        services.headscale = {
          enable = true;
          inherit (cfg) address;
          inherit (cfg) port;

          settings = {
            server_url = "https://${cfg.domain}";

            prefixes = {
              v4 = "100.64.0.0/10";
              v6 = "fd7a:115c:a1e0::/48";
            };

            derp = {
              urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
              auto_update_enabled = true;
              update_frequency = "24h";
            };

            dns = {
              magic_dns = true;
              base_domain = cfg.baseDomain;
              nameservers.global = [
                "1.1.1.1"
                "8.8.8.8"
              ];
            };

            oidc = {
              issuer = cfg.oidcIssuer;
              client_id = "headscale";
              client_secret_path = cfg.oidcClientSecretFile;
              scope = [
                "openid"
                "profile"
                "email"
              ];
              allowed_groups = cfg.allowedGroups;
            };

            log.level = "info";

            metrics_listen_addr = "${cfg.address}:${toString cfg.metricsPort}";

            database = {
              type = "postgres";
              postgres = {
                host = "/run/postgresql";
                port = 5432;
                name = "headscale";
                user = "headscale";
              };
            };

            policy = {
              mode = "file";
              path = "/etc/headscale/acl.json";
            };
          };
        };

        systemd.services.headscale = {
          restartTriggers = [ aclPolicy ];
        };

        services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
          reverse_proxy ${cfg.address}:${toString cfg.port} {
            flush_interval -1
          }
        '';

        scottylabs.postgresql.databases = [ "headscale" ];
      };
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.headscale = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          {
            terraform.backend.s3.key = "services/headscale.tfstate";
            dns = {
              headscale = {
                host = "infra-01";
                type = "CNAME";
                comment = "Headscale VPN coordination server";
              };
              headplane = {
                host = "infra-01";
                type = "CNAME";
                comment = "Headplane web UI for Headscale";
              };
            };
            resource.keycloak_openid_client = {
              headscale = {
                realm_id = "\${data.keycloak_realm.scottylabs.id}";
                client_id = "headscale";
                name = "Headscale";
                enabled = true;
                access_type = "CONFIDENTIAL";
                standard_flow_enabled = true;
                direct_access_grants_enabled = false;
                valid_redirect_uris = [ "https://headscale.scottylabs.org/oidc/callback" ];
              };
              headplane = {
                realm_id = "\${data.keycloak_realm.scottylabs.id}";
                client_id = "headplane";
                name = "Headplane";
                enabled = true;
                access_type = "CONFIDENTIAL";
                standard_flow_enabled = true;
                direct_access_grants_enabled = false;
                valid_redirect_uris = [ "https://headplane.scottylabs.org/admin/oidc/callback" ];
              };
            };

            resource.keycloak_openid_group_membership_protocol_mapper = {
              headscale_groups = {
                realm_id = "\${data.keycloak_realm.scottylabs.id}";
                client_id = "\${keycloak_openid_client.headscale.id}";
                name = "groups";
                claim_name = "groups";
                full_path = true;
              };
              headplane_groups = {
                realm_id = "\${data.keycloak_realm.scottylabs.id}";
                client_id = "\${keycloak_openid_client.headplane.id}";
                name = "groups";
                claim_name = "groups";
                full_path = true;
              };
            };

            resource.random_password.headplane_cookie.length = 32;

            resource.vault_kv_secret_v2 = {
              headscale_oidc = {
                mount = "secret";
                name = "infra/headscale-oidc";
                data_json = "\${jsonencode({ CLIENT_SECRET = keycloak_openid_client.headscale.client_secret })}";
              };
              headplane_oidc = {
                mount = "secret";
                name = "infra/headplane-oidc";
                data_json = "\${jsonencode({ CLIENT_SECRET = keycloak_openid_client.headplane.client_secret })}";
              };
              headplane_cookie = {
                mount = "secret";
                name = "infra/headplane-cookie";
                data_json = "\${jsonencode({ SECRET = random_password.headplane_cookie.result })}";
              };
            };

            output = {
              headscale_client_secret = {
                value = "\${keycloak_openid_client.headscale.client_secret}";
                sensitive = true;
              };
              headplane_client_secret = {
                value = "\${keycloak_openid_client.headplane.client_secret}";
                sensitive = true;
              };
            };
          }
        ];
      };
    };
}
