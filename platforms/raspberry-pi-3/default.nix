{ nixos-hardware, ... }:

{
  imports = [
    # Pi-specific kernel, device tree, firmware, and boot config
    nixos-hardware.nixosModules.raspberry-pi-3
    ./disk-config.nix
  ];

  # Pi 3 boots via Broadcom firmware into extlinux, not UEFI/GRUB
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Ensure USB keyboard/storage work in initrd, for recovery
  boot.initrd.availableKernelModules = [
    "usbhid"
    "usb_storage"
  ];

  # Needed for Wayland/cage compositor
  hardware.graphics.enable = true;

  # Use compressed RAM swap instead of a disk partition
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Auto-reboot if the system hangs
  systemd.watchdog.runtimeTime = "30s";
  systemd.watchdog.rebootTime = "60s";
}
