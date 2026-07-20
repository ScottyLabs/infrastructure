{ config, ... }:
{
  flake.modules.nixos.computer-club = {
    imports = [
      config.flake.modules.nixos.computer-club-disk
    ];

    # Xen kernel modules for OPC VMs
    boot.initrd.availableKernelModules = [
      "xen_blkfront"
      "xen_netfront"
    ];

    # Use GRUB for BIOS boot
    boot.loader.grub.enable = true;
  };
}
