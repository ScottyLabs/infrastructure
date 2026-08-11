{ config, ... }:
{
  flake.modules.nixos.signage-01.imports = with config.flake.modules.nixos; [
    # Platform
    mele-cyber-x1

    # Services
    signage-01-boot-screen
    signage-01-configuration
    signage-01-firefox
    signage-01-kiosk
    signage-01-reboot
    signage-01-wireless
  ];
}
