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
    webhookSecretFile = config.age.secrets.kennel-webhook-secret.path;
    environmentFile = config.age.secrets.kennel.path;

    domains = {
      ephemeral = "scottylabs.net";
      cloudflare.zones = {
        "scottylabs.org" = "ab365d7cec88f972e0b26bf59afd174f";
      };
    };

    builder.cachix = {
      enable = true;
      cacheName = "scottylabs";
    };

    resources.postgres = {
      enable = true;
      socketDir = "/run/postgresql";
    };

    secrets = {
      enable = true;
      vaultEndpoint = "https://secrets2.scottylabs.org";
    };
  };

  scottylabs.postgresql.databases = [ "kennel" ];
}
