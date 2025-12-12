{ config, lib, ... }:

{
  imports = [
    ./base.nix
    ./users.nix
    ./btrfs.nix
    ./acme.nix
    ./postgresql.nix
  ];

  # Enforce that each host must have a disk configuration defined
  assertions = [
    {
      assertion = config.disko.devices != {};
      message = "Each host must import a platform module that provides a disk configuration (e.g., platforms/campus-cloud)";
    }
  ];
}
