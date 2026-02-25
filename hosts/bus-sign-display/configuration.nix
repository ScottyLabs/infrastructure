{ ... }:

{
  imports = [
    ../../platforms/raspberry-pi-3
    ./kiosk.nix
  ];

  system.stateVersion = "25.11";
}
