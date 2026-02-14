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

  age.secrets.minio-tofu = {
    file = ../../secrets/infra-01/minio-tofu.age;
    mode = "0440"; 
    group = "tofu";
  };

  scottylabs.minio.instances.tofu = {
    port = 9100;
    consolePort = 9101; 
    credentialsFile = config.age.secrets.minio-tofu.path;
  };

  scottylabs.tofu.configurations.identity = {
    source = ../../tofu/identity;
    environmentFile = config.age.secrets.tofu-identity.path;
    after = [ "openbao.service" ];
    environment.VAULT_ADDR = "http://127.0.0.1:8200";

    extraFiles = {
      "host-projects.json" = self.packages.x86_64-linux.host-projects;
    };

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

  users.users.tofu = {
    isSystemUser = true;
    group = "tofu";
    description = "OpenTofu service user";
  };

  users.groups.tofu = { };
}
