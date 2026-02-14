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
    ./tofu-s3.nix # MinIO S3 storage + OpenTofu identity config
    ./headscale.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  system.stateVersion = "25.11";
}
