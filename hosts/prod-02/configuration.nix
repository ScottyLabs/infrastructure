{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./terrier-staging.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
