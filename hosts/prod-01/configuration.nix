{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./dalmatian.nix
    ./discord-verify.nix
    ./internet-archive.nix
    ./groupme-mirror.nix
    ./bus-sign.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
