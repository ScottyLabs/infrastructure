# tofu-s3.nix
#
# This module sets up:
# 1. A MinIO S3 bucket for storing OpenTofu configuration data (like projects.json)
# 2. The OpenTofu identity configuration that was previously in openbao.nix
#
# The idea: Instead of hardcoding JSON files in the repo (tofu/identity/projects.json),
# we can store them in S3 and have OpenTofu read them at runtime. This allows for
# more dynamic configuration without requiring repo changes.
{
  config,
  pkgs,
  self,
  ...
}:

{
  # Mostly moved from openbao.nix
  age.secrets.tofu-identity = {
    file = ../../secrets/infra-01/tofu-identity.age;
    mode = "0400"; 
  };

  # MinIO credentials secret - you'll need to create this file containing:
  #   MINIO_ROOT_USER=<username>
  #   MINIO_ROOT_PASSWORD=<password>
  # Then encrypt it with: agenix -e secrets/infra-01/minio-tofu.age
  age.secrets.minio-tofu = {
    file = ../../secrets/infra-01/minio-tofu.age;
    mode = "0440"; # Group-readable for minio service
    group = "tofu"; # The minio-tofu user needs access via this group
  };

  scottylabs.minio.instances.tofu = {
    port = 9100; # S3 API port (pick unused ports)
    consolePort = 9101; # Web UI port for managing buckets
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
