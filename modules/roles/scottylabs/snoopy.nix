{ config, ... }:
{
  flake.modules.nixos.scottylabs-snoopy.imports = with config.flake.modules.nixos; [
    # Platform
    computer-club

    # Services
    scottylabs-snoopy-configuration
  ];
}
