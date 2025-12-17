{ config, lib, pkgs, ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./dalmatian.nix
  ];

  system.stateVersion = "25.11";
}
