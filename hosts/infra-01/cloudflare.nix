{ config, ... }:

{
  age.secrets.cloudflare = {
    file = ../../secrets/infra-01/cloudflare.age;
    mode = "0400";
  };

  scottylabs.tofu.configurations.cloudflare = {
    source = ../../tofu/cloudflare;
    environmentFile = config.age.secrets.cloudflare.path;
  };
}
