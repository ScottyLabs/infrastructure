{ ... }:

{
  imports = [
    ./disk-config.nix
  ];

  # UEFI boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Needed for Wayland/cage compositor
  hardware.graphics.enable = true;
  services.seatd.enable = true;

  # Auto-reboot if the system hangs
  systemd.settings.Manager.RuntimeWatchdogSec = "30s";
  systemd.settings.Manager.RebootWatchdogSec = "60s";

  # QEMU whatnot
  virtualisation.vmVariant = {
    virtualisation.qemu.options = [
      "-device virtio-vga-gl"
      "-display sdl,gl=on"
    ];
    environment.sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1";
    };
  };

  services.qemuGuest.enable = true;
}
