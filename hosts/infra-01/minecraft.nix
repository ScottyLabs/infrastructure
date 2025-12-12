{ config, ... }:

{
  age.secrets.minecraft = {
    file = ../../secrets/infra-01/minecraft.age;
    mode = "0400";
    owner = "root";
  };

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };

  virtualisation.oci-containers = {
    backend = "docker";

    containers.minecraft = {
      image = "itzg/minecraft-server";

      environmentFiles = [
        config.age.secrets.minecraft.path
      ];

      environment = {
        EULA = "TRUE";
        TYPE = "AUTO_CURSEFORGE";
        CF_SLUG = "society-sunlit-valley";
        MEMORY = "8G";
        TZ = "America/New_York";
        ALLOW_FLIGHT = "true";
        OPS = "cerulean3910";
        MOTD = "Society: Sunlit Valley";
        ENABLE_RCON = "true";
        # RCON_PASSWORD comes from environmentFiles
      };

      volumes = [
        "/var/lib/minecraft:/data"
        "/var/lib/minecraft-downloads:/downloads"
      ];

      ports = [ "25565:25565" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/minecraft 0755 root root -"
    "d /var/lib/minecraft-downloads 0755 root root -"
  ];

  networking.firewall.allowedTCPPorts = [ 25565 ];
}

