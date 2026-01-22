{ config, ... }:

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
}
