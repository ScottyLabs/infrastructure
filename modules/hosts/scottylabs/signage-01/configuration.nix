{
  flake.modules.nixos.scottylabs-signage-01-configuration = {
    scottylabs.ipAddress = "172.24.97.209";
    scottylabs.bastion = "infra-01.scottylabs.org";

    # Enable fonts for kiosk Firefox rendering that srvos server profile disables
    fonts.fontconfig.enable = true;

    system.stateVersion = "25.11";
  };
}
