{ config, ... }:

{
  imports = [
    ./base.nix
    ./users.nix
    ./btrfs.nix
    ./comin.nix
    ./acme.nix
    ./postgresql.nix
    ./valkey.nix
    ./minio.nix
    ./tofu.nix
    ./bao-agent.nix
    ./tailscale.nix
  ];

  # Enforce that each host must have a disk configuration defined
  assertions = [
    {
      assertion = config.disko.devices != { };
      message = "Each host must import a platform module that provides a disk configuration (e.g., platforms/campus-cloud)";
    }
  ];
}
