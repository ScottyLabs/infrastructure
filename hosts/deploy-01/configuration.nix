{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./dalmatian.nix
    ./discord-verify.nix
    ./internet-archive.nix
    ./groupme-mirror.nix
    ./voting-app.nix
    ./saml-proxy.nix
    ./terrier-docs.nix
    ./kennel.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
