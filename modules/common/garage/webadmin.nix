{ config, ... }:
{
  flake.modules.nixos.webadmin =
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
    in
    {
      options.scottylabs.garage.webadmin = {
        enable = lib.mkEnableOption "Garage Web Admin UI behind a Keycloak login";

        domain = lib.mkOption {
          type = lib.types.str;
          description = "Public hostname for the Garage Web Admin UI";
        };
      };

      config = lib.mkIf (cfg.enable && cfg.webadmin.enable) {
        scottylabs.caddy.sso.sites.garage-webadmin.domain = cfg.webadmin.domain;

        services.caddy.virtualHosts.${cfg.webadmin.domain}.extraConfig = ''
          route /api/* {
            uri strip_prefix /api
            reverse_proxy 127.0.0.1:${toString cfg.adminPort}
          }

          route {
            root * ${webadminPackage}
            try_files {path} /index.html
            file_server
          }
        '';
      };
    };

  perSystem =
    { pkgs, ... }:
    {
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
