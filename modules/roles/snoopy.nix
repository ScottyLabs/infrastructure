{ config, ... }:
{
  flake.modules.nixos.snoopy.imports = with config.flake.modules.nixos; [
    computer-club
    snoopy-configuration
  ];
}
