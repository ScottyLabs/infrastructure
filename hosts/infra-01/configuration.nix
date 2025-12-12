{ config, lib, pkgs, ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./minecraft.nix
    ./keycloak.nix
  ];

  system.stateVersion = "25.11";
}
