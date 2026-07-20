{ config, ... }:
{
  flake.modules.nixos.raspberry-pi-3 =
    { inputs, ... }:
    {
      imports = [
        # Pi-specific kernel, device tree, firmware, and boot config
        inputs.nixos-hardware.nixosModules.raspberry-pi-3
        config.flake.modules.nixos.raspberry-pi-3-disk
        config.flake.modules.nixos.zram-swap
      ];

      # Pi 3 boots via Broadcom firmware into extlinux
      boot.loader.grub.enable = false;
      boot.loader.generic-extlinux-compatible.enable = true;

      # USB keyboard and storage in initrd
      boot.initrd.availableKernelModules = [
        "usbhid"
        "usb_storage"
      ];
    };
}
