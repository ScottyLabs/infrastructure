{ config, lib, pkgs, ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./minecraft.nix
  ];

  system.stateVersion = "25.11";
}
