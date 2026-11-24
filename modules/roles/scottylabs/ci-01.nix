{ config, ... }:
{
  flake.modules.nixos.scottylabs-ci-01.imports = with config.flake.modules.nixos; [
    # Platform
    occ

    # Services
    scottylabs-ci-01-configuration
    scottylabs-ci-01-runner
  ];
}
