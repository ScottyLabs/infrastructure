{ kennel, ... }:

{
  imports = [
    kennel.nixosModules.default
  ];

  scottylabs.bao-agent = {
    enable = true;
    secrets.kennel = {
      project = "kennel";
      user = "kennel";
    };
  };

  services.kennel = {
    enable = true;
    package = kennel.packages.x86_64-linux.kennel;
    database.createLocally = false;

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
        authTokenFile = "/run/secrets/cachix-auth-token";
      };
    };

    dns = {
      enable = true;
      cloudflare = {
        apiTokenFile = "/run/secrets/cloudflare-api-token";
        zones = {
          "scottylabs.org" = "f8b0a968c44462e7f9128ad43151d2c4";
        };
      };
      serverIpv4 = "128.2.25.68";
    };
  };

  systemd.services.kennel = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };

  scottylabs.postgresql.databases = [ "kennel" ];
}
