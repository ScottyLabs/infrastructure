{ config, ... }:
{
  flake.modules.nixos.thetartan-tartan-01.imports = with config.flake.modules.nixos; [
    # Platform
    campus-cloud

    # Services
    thetartan-tartan-01-configuration
  ];
}
