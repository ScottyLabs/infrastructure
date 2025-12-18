{ config, lib, pkgs, ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./dalmatian.nix
    ./discord-verify.nix
  ];

  system.stateVersion = "25.11";
}
