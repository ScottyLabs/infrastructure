{ config, lib, pkgs, ... }:

{
  age.secrets.vaultwarden = {
    file = ../../secrets/infra-01/vaultwarden.age;
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
      SMTP_HOST = "smtp.mailgun.org";
      SMTP_FROM = "vaultwarden@mail.scottylabs.org";
      SMTP_FROM_NAME = "ScottyLabs Vaultwarden";
      SMTP_SECURITY = "starttls";
      SMTP_PORT = 587;
      SMTP_TIMEOUT = 15;

      # Database via Unix socket
      DATABASE_URL = "postgresql:///vaultwarden?host=/run/postgresql";
    };

    # SMTP_USERNAME, SMTP_PASSWORD, ADMIN_TOKEN
    environmentFile = config.age.secrets.vaultwarden.path;
  };

  services.nginx.virtualHosts."vault.scottylabs.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8222";
      proxyWebsockets = true;
    };
  };

  scottylabs.postgresql.databases = [ "vaultwarden" ];
}
