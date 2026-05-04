{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.garage;

  webadminSrc = pkgs.fetchgit {
    url = "https://git.deuxfleurs.fr/Deuxfleurs/garage-webadmin.git";
    rev = "fcee2014622df4c637bd12c71863d18084ceeec6";
    hash = "sha256-3iCEYN5hbsJ0vUCLMEVp1AcQBhPx6jKbsq+3WMwK4OE=";
  };

  webadminPackage = pkgs.buildNpmPackage {
    pname = "garage-webadmin";
    version = "fcee201";
    src = webadminSrc;
    npmDepsHash = "sha256-ZilGzsObltRTcnM7gcacqwrfJzUIKy0Sin/kR9FlVII=";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/. $out/
      runHook postInstall
    '';
  };

  caddyWithSecurity = pkgs.caddy.withPlugins {
    plugins = [ "github.com/greenpau/caddy-security@v1.1.62" ];
    hash = "sha256-NpVNGD8y9yW69/i5dXDuN6yuyIe37KHsrMbt7g5povk=";
  };
in
{
  options.scottylabs.garage = {
    enable = lib.mkEnableOption "Garage S3-compatible object storage";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to environment file containing:
        - GARAGE_RPC_SECRET=<32-byte hex string>
        - GARAGE_ADMIN_TOKEN=<admin bearer token>
      '';
    };

    s3Port = lib.mkOption {
      type = lib.types.port;
      default = 3900;
      description = "Port for the S3 API";
    };

    rpcPort = lib.mkOption {
      type = lib.types.port;
      default = 3901;
      description = "Port for internal RPC";
    };

    adminPort = lib.mkOption {
      type = lib.types.port;
      default = 3903;
      description = "Port for the admin API";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 3902;
      description = ''
        Port for the s3_web (anonymous public-read) API. Serves only
        buckets that have been flagged via PutBucketWebsite. Routes
        requests to a bucket by matching the Host header against the
        bucket's globalAlias.
      '';
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "s3.scottylabs.org";
      description = "Domain name for the S3 API endpoint";
    };

    webadmin = {
      enable = lib.mkEnableOption "Garage Web Admin UI fronted by caddy with Keycloak OIDC";

      domain = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname for the Garage Web Admin UI";
      };

      keycloakRealm = lib.mkOption {
        type = lib.types.str;
        default = "scottylabs";
        description = "Keycloak realm hosting the OIDC client";
      };

      keycloakIssuerBase = lib.mkOption {
        type = lib.types.str;
        default = "https://idp.scottylabs.org";
        description = "Keycloak base URL without the realm path";
      };

      environmentFile = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/garage-webadmin.env";
        description = ''
          Env file consumed by caddy. Must define OIDC_CLIENT_SECRET and
          JWT_SHARED_KEY. By default this is the bao-agent rendered file
          for the garage-webadmin project secrets in OpenBao.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.garage = {
        enable = true;
        package = pkgs.garage_2;

        inherit (cfg) environmentFile;

        settings = {
          replication_factor = 1;

          rpc_bind_addr = "[::]:${toString cfg.rpcPort}";

          s3_api = {
            s3_region = "us-east-1";
            api_bind_addr = "[::]:${toString cfg.s3Port}";
          };

          s3_web = {
            bind_addr = "[::]:${toString cfg.webPort}";
            # An empty root_domain makes bucket lookup a full Host-header
            # match against the bucket's globalAlias. Per-bucket caddy
            # vhosts handle public hostname mapping by rewriting Host.
            root_domain = "";
          };

          admin = {
            api_bind_addr = "[::]:${toString cfg.adminPort}";
          };
        };
      };

      services.caddy = {
        enable = true;
        virtualHosts.${cfg.domain}.extraConfig = ''
          request_body {
            max_size 100MB
          }
          reverse_proxy localhost:${toString cfg.s3Port}
        '';
      };
    })

    (lib.mkIf (cfg.enable && cfg.webadmin.enable) {
      services.caddy = {
        package = caddyWithSecurity;

        globalConfig = ''
          order authenticate before respond
          order authorize before basicauth

          security {
            oauth identity provider keycloak {
              driver generic
              realm ${cfg.webadmin.keycloakRealm}
              client_id garage-webadmin
              client_secret {env.OIDC_CLIENT_SECRET}
              scopes openid email profile
              metadata_url ${cfg.webadmin.keycloakIssuerBase}/realms/${cfg.webadmin.keycloakRealm}/.well-known/openid-configuration
            }

            authentication portal garageportal {
              crypto default token lifetime 3600
              crypto key sign-verify {env.JWT_SHARED_KEY}
              enable identity provider keycloak
              cookie domain ${cfg.webadmin.domain}
              transform user {
                match origin keycloak
                action add role authp/user
              }
            }

            authorization policy garagepolicy {
              set auth url https://${cfg.webadmin.domain}/auth/
              allow roles authp/user
              crypto key verify {env.JWT_SHARED_KEY}
            }
          }
        '';

        virtualHosts.${cfg.webadmin.domain}.extraConfig = ''
          route /auth* {
            authenticate with garageportal
          }

          route /api/* {
            authorize with garagepolicy
            uri strip_prefix /api
            reverse_proxy 127.0.0.1:${toString cfg.adminPort}
          }

          route {
            authorize with garagepolicy
            root * ${webadminPackage}
            try_files {path} /index.html
            file_server
          }
        '';
      };

      systemd.services.caddy = {
        # Leading "-" makes the env file optional. On first deploy the file
        # has not yet been rendered by bao-agent (which depends on
        # tofu-identity having run, which depends on caddy already serving
        # idp.scottylabs.org), and a hard requirement here would break every
        # caddy-served vhost. Once the file appears, run
        # `systemctl restart caddy` to pick up the OIDC env vars.
        serviceConfig.EnvironmentFile = [
          "-${cfg.webadmin.environmentFile}"
        ];
        after = [ "bao-agent.service" ];
        wants = [ "bao-agent.service" ];
      };
    })
  ];
}
