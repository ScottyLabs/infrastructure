{ lib, ... }:

{
  imports = [
    ../../platforms/mele-cyber-x1
    ./kiosk.nix
    ./boot-screen.nix
    ../../common/firefox.nix
  ];

  # srvos server profile disables fonts/XDG for headless servers,
  # but this kiosk needs them for Firefox rendering
  fonts.fontconfig.enable = true;

  system.stateVersion = "25.11";

  # Disable bao
  scottylabs.bao-agent = {
    enable = lib.mkForce false;
  };
}
