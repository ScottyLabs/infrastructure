{ discord-verify, ... }:

{
  imports = [ discord-verify.nixosModules.default ];

  scottylabs.bao-agent = {
    enable = true;
    secrets.discord-verify = {
      project = "discord-verify";
      user = "discord-verify";
    };
  };

  services.discord-verify = {
    enable = true;
    environmentFile = "/run/secrets/discord-verify.env";
  };

  services.nginx = {
    enable = true;

    virtualHosts."verify.scottylabs.org" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:3000";
        proxyWebsockets = true;
      };
    };
  };

  scottylabs.valkey.servers = [ "discord-verify" ];
}
