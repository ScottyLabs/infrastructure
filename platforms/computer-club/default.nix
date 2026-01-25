{...}:

{
  imports = [
    ./disk-config.nix
  ];

  # Xen kernel modules for OPC VMs
  boot.initrd.availableKernelModules = [ "xen_blkfront" "xen_netfront" ];

  # Use GRUB for BIOS boot
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/xvda" ];
  boot.loader.grub.mirroredBoots = [];
}
