{ config, ... }:
{
  flake.modules.nixos.deploy-01.imports = with config.flake.modules.nixos; [
    campus-cloud
    deploy-01-configuration
    deploy-01-kennel
    deploy-01-garage
    deploy-01-ricochet

    server
    webadmin
    postgresql
    valkey
  ];
}
