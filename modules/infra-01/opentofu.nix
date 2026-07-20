{
  flake.modules.nixos.infra-01-opentofu =
    { config, ... }:

    {
      age.secrets.tofu-cloudflare = {
        file = ../../secrets/infra-01/tofu-cloudflare.age;
        mode = "0400";
      };

      age.secrets.tofu-state-s3 = {
        file = ../../secrets/infra-01/tofu-state-s3.age;
        mode = "0400";
      };

      scottylabs.tofu.configurations.cloudflare = {
        source = ../../tofu/cloudflare;
        environmentFile = [
          config.age.secrets.tofu-cloudflare.path
          config.age.secrets.tofu-state-s3.path
        ];
      };
    };
}
