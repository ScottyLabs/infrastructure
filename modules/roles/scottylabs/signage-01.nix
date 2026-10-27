{ config, ... }:
{
  flake.modules.nixos.scottylabs-signage-01.imports = with config.flake.modules.nixos; [
    # Platform
    mele-cyber-x1

    # Services
    scottylabs-signage-01-boot-screen
    scottylabs-signage-01-configuration
    scottylabs-signage-01-firefox
    scottylabs-signage-01-kiosk
    scottylabs-signage-01-reboot
    scottylabs-signage-01-wireless
  ];
}
