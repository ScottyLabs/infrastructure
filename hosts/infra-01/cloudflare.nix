{ config, ... }:

{
  age.secrets.tofu-cloudflare = {
    file = ../../secrets/infra-01/tofu-cloudflare.age;
    mode = "0400";
  };

  scottylabs.tofu.configurations.cloudflare = {
    source = ../../tofu/cloudflare;
    environmentFile = config.age.secrets.tofu-cloudflare.path;
  };
}
