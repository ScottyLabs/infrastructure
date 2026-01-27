{
  config,
  pkgs,
  self,
  ...
}:

{
  age.secrets.tofu-identity = {
    file = ../../secrets/infra-01/tofu-identity.age;
    mode = "0400";
  };

  services.openbao = {
    enable = true;
    settings = {
      ui = true;
      listener.default = {
        type = "tcp";
        address = "127.0.0.1:8200";
        tls_disable = true;
      };

      storage.postgresql.connection_url = "postgresql:///openbao?host=/run/postgresql&user=openbao";

      log_level = "debug";

      cluster_name = "default";
      cluster_addr = "http://127.0.0.1:8201";

      api_addr = "https://secrets2.scottylabs.org";
    };
  };

  # Creates the JWT auth backend + role for Keycloak and configures project groups
  scottylabs.tofu.configurations.identity = {
    source = ../../tofu/identity;
    environmentFile = config.age.secrets.tofu-identity.path;
    after = [ "openbao.service" ];
    environment.VAULT_ADDR = "http://127.0.0.1:8200";

    extraFiles = {
      "host-projects.json" = self.packages.x86_64-linux.host-projects;
    };

    # OpenBao must be unsealed before we can configure it
    preCheck = ''
      for i in $(seq 1 60); do
        if ${pkgs.openbao}/bin/bao status 2>/dev/null | grep -q "Sealed.*false"; then
          echo "OpenBao is unsealed"
          exit 0
        fi
        echo "Waiting for OpenBao to be unsealed... ($i/60)"
        sleep 5
      done
      echo "OpenBao still sealed after 5 minutes, skipping configuration"
      exit 1
    '';
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
