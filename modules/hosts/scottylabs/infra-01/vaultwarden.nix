{ config, ... }:
{
  flake.modules.nixos.scottylabs-infra-01-vaultwarden =
    { config, ... }:

    {
      age.secrets.vaultwarden = {
        file = ../../../../secrets/scottylabs/infra-01/vaultwarden.age;
        mode = "0400";
        owner = "vaultwarden";
      };

      services.vaultwarden = {
        enable = true;
        dbBackend = "postgresql";

        config = {
          DOMAIN = "https://vault.scottylabs.org";
          SIGNUPS_ALLOWED = false;
          INVITATIONS_ALLOWED = true;
          SHOW_PASSWORD_HINT = false;
          LOG_LEVEL = "info";
          EXTENDED_LOGGING = true;
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = 8222;

          # SMTP
          SMTP_HOST = "smtp.mx.cloudflare.net";
          SMTP_FROM = "noreply@scottylabs.org";
          SMTP_FROM_NAME = "ScottyLabs Vaultwarden";
          SMTP_SECURITY = "force_tls";
          SMTP_PORT = 465;
          SMTP_USERNAME = "api_token";
          SMTP_PASSWORD_FILE = "/run/credentials/vaultwarden.service/smtp";
          SMTP_TIMEOUT = 15;

          # Database via Unix socket
          DATABASE_URL = "postgresql:///vaultwarden?host=/run/postgresql";
        };

        # ADMIN_TOKEN
        environmentFile = config.age.secrets.vaultwarden.path;
      };

      systemd.services.vaultwarden.vault.infraSecrets.smtp = {
        path = "cloudflare-smtp";
        key = "TOKEN";
      };

      services.caddy.virtualHosts."vault.scottylabs.org".extraConfig = ''
        reverse_proxy 127.0.0.1:8222
      '';

      scottylabs.postgresql.databases = [ "vaultwarden" ];
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.vaultwarden = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/vaultwarden.tfstate";
            dns.vault = {
              name = "vault";
              tunnel = "scottylabs-infra-01";
              comment = "Vaultwarden";
            };
          }
        ];
      };
    };
}
