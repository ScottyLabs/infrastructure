{ nixos-hardware, ... }:

{
  imports = [
    # Pi-specific kernel, device tree, firmware, and boot config
    nixos-hardware.nixosModules.raspberry-pi-3
    ./disk-config.nix
    ../../common/zram-swap.nix
  ];

  # Pi 3 boots via Broadcom firmware into extlinux
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # USB keyboard and storage in initrd
  boot.initrd.availableKernelModules = [
    "usbhid"
    "usb_storage"
  ];

  # Needed for wayland/cage compositor
  hardware.graphics.enable = true;
}
