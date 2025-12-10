{ config, lib, pkgs, ... }:

{
  imports = [
    ../../platforms/campus-cloud
  ];

  system.stateVersion = "25.11";
}
