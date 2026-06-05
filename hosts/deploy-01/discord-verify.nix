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
    enable = false;
    environmentFile = "/run/secrets/discord-verify.env";
  };

  scottylabs.valkey.servers = [ "discord-verify" "kennel" ];
}
