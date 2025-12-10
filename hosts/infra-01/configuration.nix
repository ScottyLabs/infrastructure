{ config, lib, pkgs, ... }:

{
  system.stateVersion = "25.11";

  virtualisation.vmware.guest.enable = true;
}
