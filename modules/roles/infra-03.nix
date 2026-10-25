{ config, ... }:
{
  flake.modules.nixos.infra-03.imports = with config.flake.modules.nixos; [
    # Platform
    occ

    # Services
    infra-03-configuration
    infra-03-runner
  ];
}
