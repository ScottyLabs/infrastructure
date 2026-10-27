{ config, ... }:
{
  flake.modules.nixos.scottylabs-infra-03.imports = with config.flake.modules.nixos; [
    # Platform
    occ

    # Services
    scottylabs-infra-03-configuration
    scottylabs-infra-03-runner
  ];
}
