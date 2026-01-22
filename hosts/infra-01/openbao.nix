{ lib, ... }:

{
  services.openbao = {
    enable = true;
    settings = {
      ui = true;
      listener.default = {
        type = "tcp";
        address = "127.0.0.1:8200";
        tls_disable = true;
      };

      storage.postgresql.connection_url = "postgresql://openbao@localhost/openbao?sslmode=disable";

      log_level = "debug";

      cluster_name = "default";
      cluster_addr = "http://127.0.0.1:8201";

      api_addr = "https://secrets2.scottylabs.org";
    };
  };

  services.nginx.virtualHosts."secrets2.scottylabs.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8200";
      proxyWebsockets = true;
    };
  };

  scottylabs.postgresql.databases = [ "openbao" ];

  # Create a static user because the openbao module uses a dynamic one
  users.users.openbao = {
    isSystemUser = true;
    group = "openbao";
    home = "/var/lib/openbao";
  };
  users.groups.openbao = {};

  systemd.services.openbao.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "openbao";
    Group = "openbao";
  };
}
