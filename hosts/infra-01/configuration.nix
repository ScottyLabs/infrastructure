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
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
