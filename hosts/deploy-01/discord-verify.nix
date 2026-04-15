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

  systemd.services.discord-verify = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };

  services.caddy.virtualHosts."verify.scottylabs.org".extraConfig = ''
    reverse_proxy localhost:3000
  '';

  scottylabs.valkey.servers = [ "discord-verify" ];
}
