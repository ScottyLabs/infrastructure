{ config, pkgs, ... }:

{
  age.secrets = {
    tofu-cloudflare = {
      file = ../../secrets/infra-01/tofu-cloudflare.age;
      mode = "0400";
    };
    tofu-tailscale = {
      file = ../../secrets/infra-01/tofu-tailscale.age;
      mode = "0400";
    };
  };

  scottylabs.tofu.configurations = {
    cloudflare = {
      source = ../../tofu/cloudflare;
      environmentFile = config.age.secrets.tofu-cloudflare.path;
    };
    tailscale = {
      source = ../../tofu/tailscale;
      environmentFile = config.age.secrets.tofu-tailscale.path;
      after = [ "openbao.service" ];
      environment.VAULT_ADDR = "http://127.0.0.1:8200";

      preCheck = ''
        for i in $(seq 1 60); do
          if ${pkgs.openbao}/bin/bao status 2>/dev/null | grep -q "Sealed.*false"; then
            exit 0
          fi
          sleep 5
        done
        exit 1
      '';
    };
  };
}
