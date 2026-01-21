{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./dalmatian.nix
    ./discord-verify.nix
    ./internet-archive.nix
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  system.stateVersion = "25.11";
}
