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

  services.kennel = {
    enable = true;
    package = kennel.packages.x86_64-linux.kennel;
    database.createLocally = false;
    environmentFile = config.age.secrets.kennel.path;

    router = {
      baseDomain = "scottylabs.org";
      tls = {
        enable = true;
        email = "admin@scottylabs.org";
      };
    };

    builder = {
      cachix = {
        enable = true;
        cacheName = "scottylabs";
      };
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

  scottylabs.postgresql.databases = [ "kennel" ];
}
