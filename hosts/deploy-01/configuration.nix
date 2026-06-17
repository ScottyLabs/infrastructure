{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./internet-archive.nix
    # ./saml-proxy.nix
    # ./terrier-docs.nix
    ./kennel.nix
    ./ricochet.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
