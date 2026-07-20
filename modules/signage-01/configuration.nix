{
  flake.modules.nixos.signage-01-configuration = {
    networking.hostName = "signage-01";

    # Enable fonts for kiosk Firefox rendering that srvos server profile disables
    fonts.fontconfig.enable = true;

    system.stateVersion = "25.11";
  };
}
