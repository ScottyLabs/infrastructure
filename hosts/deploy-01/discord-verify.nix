{ ... }:

{
  scottylabs.bao-agent = {
    enable = true;
    secrets.discord-verify = {
      project = "discord-verify";
      user = "discord-verify";
    };
  };

  users.users.discord-verify = {
    isSystemUser = true;
    group = "discord-verify";
  };
  users.groups.discord-verify = { };

  scottylabs.valkey.servers = [ "discord-verify" "kennel" ];
}
