{ config, ... }:
{
  flake.modules.nixos.deploy-01.imports = with config.flake.modules.nixos; [
    # Platform
    campus-cloud

    # Common
    postgresql
    server
    webadmin

    # Services
    deploy-01-configuration
    deploy-01-garage
    deploy-01-kennel
    deploy-01-ricochet
    deploy-01-valkey
  ];
}
