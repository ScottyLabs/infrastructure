{ lib, ... }:

{
  imports = [
    ../../platforms/mele-cyber-x1
    ./kiosk.nix
    ./boot-screen.nix
    ../../common/firefox.nix
  ];

  # Enable fonts for kiosk Firefox rendering that srvos server profile disables
  fonts.fontconfig.enable = true;

  system.stateVersion = "25.11";

  # Disable bao
  scottylabs.bao-agent = {
    enable = lib.mkForce false;
  };
}
