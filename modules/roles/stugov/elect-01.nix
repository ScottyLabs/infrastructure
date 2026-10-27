{ config, ... }:
{
  flake.modules.nixos.stugov-elect-01.imports = with config.flake.modules.nixos; [
    # Platform
    campus-cloud

    # Services
    stugov-elect-01-configuration
  ];
}
