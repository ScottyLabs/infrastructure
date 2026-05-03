{ config, ... }:

{
  scottylabs.garage = {
    enable = true;
    environmentFile = config.age.secrets.garage.path;
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

  # Public, anonymous-read entry point for the scottylabs-assets bucket.
  # Garage matches buckets by Host header on its s3_web listener, so nginx
  # rewrites Host to the bucket's globalAlias when proxying.
  services.nginx.virtualHosts."assets.scottylabs.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${toString config.scottylabs.garage.webPort}";
      extraConfig = ''
        proxy_set_header Host scottylabs-assets;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
