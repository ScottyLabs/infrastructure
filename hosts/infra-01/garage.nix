{ config, ... }:

{
  scottylabs.garage = {
    enable = true;
    environmentFile = config.age.secrets.garage.path;
    webadmin = {
      enable = true;
      domain = "garage.scottylabs.org";
    };
  };

  scottylabs.bao-agent = {
    enable = true;
    infraSecrets = {
      garage-webadmin-oidc = {
        path = "garage-webadmin-oidc";
        key = "CLIENT_SECRET";
        user = "caddy";
      };
      garage-webadmin-jwt = {
        path = "garage-webadmin-jwt";
        key = "SECRET";
        user = "caddy";
      };
    };
  };

  age.secrets.garage = {
    file = ../../secrets/infra-01/garage.age;
    mode = "0400";
  };

  age.secrets.tofu-garage = {
    file = ../../secrets/infra-01/tofu-garage.age;
    mode = "0400";
  };

  scottylabs.tofu.configurations.garage = {
    source = ../../tofu/garage;
    environmentFile = config.age.secrets.tofu-garage.path;
    after = [ "garage.service" ];
  };

  # Public anonymous-read entry point for the scottylabs-assets bucket.
  # Garage matches buckets by Host header on its s3_web listener, so caddy
  # rewrites Host to the bucket's globalAlias when proxying.
  services.caddy.virtualHosts."assets.scottylabs.org".extraConfig = ''
    reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
      header_up Host scottylabs-assets
    }
  '';
}
