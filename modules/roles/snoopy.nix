{ config, ... }:
{
  flake.modules.nixos.snoopy.imports = with config.flake.modules.nixos; [
    # Platform
    computer-club

    # Services
    snoopy-configuration
  ];
}
