{ config, lib, pkgs, ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./minecraft.nix
    ./keycloak.nix
  ];

  scottylabs.postgresql.databases = [
    "keycloak"
  ];

  system.stateVersion = "25.11";
}
