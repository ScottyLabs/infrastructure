{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./forgejo-ci.nix
    ./keycloak.nix
    ./vaultwarden.nix
    ./openbao.nix
    ./opentofu.nix
    ./tailnet.nix
    ./matrix.nix
    ./garage.nix
    ./atlantis
    ./ai-gateway.nix
    ./observability.nix
    ./uptime.nix
    ./cmu-vpn
  ];

  # Allow building aarch64 packages via QEMU emulation
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
