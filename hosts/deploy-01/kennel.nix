{ config, kennel, ... }:

{
  imports = [
    kennel.nixosModules.default
  ];

  age.secrets.kennel = {
    file = ../../secrets/deploy-01/kennel.age;
    owner = "kennel";
    group = "kennel";
    mode = "0440";
  };

  age.secrets.kennel-webhook-secret = {
    file = ../../secrets/deploy-01/kennel-webhook-secret.age;
    owner = "kennel";
    group = "kennel";
    mode = "0400";
  };

  services.kennel = {
    enable = true;
    package = kennel.packages.x86_64-linux.kennel;
    database.createLocally = false;
    environmentFile = config.age.secrets.kennel.path;

    api.port = 3001;

    router = {
      address = "0.0.0.0:8090";
      baseDomain = "scottylabs.org";
      # tls = {
      #   enable = true;
      #   email = "admin@scottylabs.org";
      # };
    };

    builder = {
      cachix = {
        enable = true;
        cacheName = "scottylabs";
      };
    };

    projects.kennel = {
      repoUrl = "https://codeberg.org/ScottyLabs/kennel";
      repoType = "forgejo";
      webhookSecretFile = config.age.secrets.kennel-webhook-secret.path;
    };

    dns = {
      enable = true;
      cloudflare = {
        zones = {
          "scottylabs.org" = "f8b0a968c44462e7f9128ad43151d2c4";
        };
      };
      serverIpv4 = "128.2.25.68";
    };
  };

  services.nginx.virtualHosts."kennel.scottylabs.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/webhook" = {
      proxyPass = "http://localhost:3001";
    };
  };

  scottylabs.postgresql.databases = [ "kennel" ];
}
