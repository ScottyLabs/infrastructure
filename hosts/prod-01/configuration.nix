{ config, lib, pkgs, ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./dalmatian.nix
    ./discord-verify.nix
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  system.stateVersion = "25.11";
}
