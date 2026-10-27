{ config, ... }:
{
  flake.modules.nixos.thetartan-www-04.imports = with config.flake.modules.nixos; [
    # Platform
    campus-cloud

    # Services
    thetartan-www-04-configuration
  ];
}
