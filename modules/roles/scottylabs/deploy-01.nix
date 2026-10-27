{ config, ... }:
{
  flake.modules.nixos.scottylabs-deploy-01.imports = with config.flake.modules.nixos; [
    # Platform
    campus-cloud

    # Common
    postgresql
    server
    webadmin

    # Services
    scottylabs-deploy-01-configuration
    scottylabs-deploy-01-garage
    scottylabs-deploy-01-kennel
    scottylabs-deploy-01-ricochet
    scottylabs-deploy-01-valkey
  ];
}
