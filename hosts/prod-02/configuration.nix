{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./saml-proxy.nix
    ./terrier-docs.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
