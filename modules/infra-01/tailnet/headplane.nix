{
  flake.modules.nixos.headplane =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.tailnet.headplane;
      headscaleCfg = config.scottylabs.tailnet.headscale;

      headscaleConfigForHeadplane = (pkgs.formats.yaml { }).generate "headscale.yml" (
        lib.recursiveUpdate config.services.headscale.settings {
          tls_cert_path = "";
          tls_key_path = "";
        }
      );
    in
    {
      options.scottylabs.tailnet.headplane = {
        enable = lib.mkEnableOption "Headplane web UI for Headscale";

        domain = lib.mkOption {
          type = lib.types.str;
          default = "headplane.scottylabs.org";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 3100;
        };

        cookieSecretFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to a file containing the Headplane cookie secret.";
        };

        oidcClientSecretFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to Keycloak OIDC client_secret for headplane.";
        };

        apiKeyFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to a file containing a Headscale API key for headplane.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.headplane = {
          enable = true;
          settings = {
            server = {
              inherit (cfg) host;
              inherit (cfg) port;
              cookie_secret_path = cfg.cookieSecretFile;
              base_url = "https://${cfg.domain}";
            };

            headscale = {
              url = "https://${headscaleCfg.domain}";
              config_path = "${headscaleConfigForHeadplane}";
              config_strict = false;
              api_key_path = cfg.apiKeyFile;
            };

            oidc = {
              issuer = headscaleCfg.oidcIssuer;
              client_id = "headplane";
              client_secret_path = cfg.oidcClientSecretFile;
              disable_api_key_login = false;
            };

            integration = {
              proc.enabled = true;
              agent = {
                enabled = true;
              };
            };
          };
        };

        systemd.services.headplane = {
          after = [
            "headscale.service"
          ];
          wants = [
            "headscale.service"
          ];
        };

        services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
          reverse_proxy ${cfg.host}:${toString cfg.port}
        '';
      };
    };
}
