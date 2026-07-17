{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./kennel.nix
    ./garage.nix
    ./ricochet.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
