{ config, discord-verify, ... }:

{
  imports = [ discord-verify.nixosModules.default ];

  age.secrets.discord-verify = {
    file = ../../secrets/prod-01/discord-verify.age;
    mode = "0400";
    owner = "discord-verify";
  };

  services.discord-verify = {
    enable = true;
    environmentFile = config.age.secrets.discord-verify.path;
  };

  scottylabs.valkey.servers = [ "discord-verify" ];
}
