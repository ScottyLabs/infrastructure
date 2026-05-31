{ lib, ... }:

{
  imports = [
    ../../platforms/mele-cyber-x1
    ./kiosk.nix
    ./boot-screen.nix
    ../../common/firefox.nix
  ];

  system.stateVersion = "25.11";

  # Disable bao
  scottylabs.bao-agent = {
    enable = lib.mkForce false;
  };
}
