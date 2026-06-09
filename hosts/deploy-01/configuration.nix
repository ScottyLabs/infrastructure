{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    # for dalmatian and discord-verify, ensure data is fully migrated before deleting
    ./dalmatian.nix
    ./discord-verify.nix
    ./internet-archive.nix
    # ./saml-proxy.nix
    # ./terrier-docs.nix
    ./kennel.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
