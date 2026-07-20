{ config, ... }:
{
  flake.modules.nixos.signage-01.imports = with config.flake.modules.nixos; [
    mele-cyber-x1
    signage-01-configuration
    signage-01-kiosk
    signage-01-boot-screen
    signage-01-firefox
  ];
}
