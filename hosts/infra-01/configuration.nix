{ config, lib, pkgs, ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./minecraft.nix
    ./keycloak.nix
    ./vaultwarden.nix
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  system.stateVersion = "25.11";
}
