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

  age.secrets.kennel-forgejo-token = {
    file = ../../secrets/deploy-01/kennel-forgejo-token.age;
    owner = "kennel";
    group = "kennel";
    mode = "0400";
  };

  services.kennel = {
    enable = true;
    package = kennel.packages.x86_64-linux.kennel;
    devenvPackage = kennel.packages.x86_64-linux.devenv;
    webhookSecretFile = config.age.secrets.kennel-webhook-secret.path;
    environmentFile = config.age.secrets.kennel.path;
    api.port = 3001;

    domains = {
      ephemeral = "scottylabs.net";
      cloudflare = {
        publicIp = "128.2.25.68";
        zones = {
          "scottylabs.org" = "ab365d7cec88f972e0b26bf59afd174f";
          "cmu.quest" = "dbedf6cff671263c0d6f69b482895ee4";
        };
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
      vaultEndpoint = "vault://secrets2.scottylabs.org/secret?auth=approle";
    };

    forgejo.apiTokenFile = config.age.secrets.kennel-forgejo-token.path;
  };

  scottylabs.postgresql.databases = [ "kennel" ];
}
