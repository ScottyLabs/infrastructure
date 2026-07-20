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
          after = [ "bao-agent.service" ];
          wants = [ "bao-agent.service" ];
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
}
