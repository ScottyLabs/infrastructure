{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./flake-webhook.nix
    ./forgejo-runner.nix
    ./minecraft.nix
    ./keycloak.nix
    ./vaultwarden.nix
    ./openbao.nix
    ./opentofu.nix
    ./headscale.nix
  ];

  # Allow building aarch64 packages via QEMU emulation
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
