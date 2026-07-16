{ srvos, ... }:

{
  imports = [
    ./disk-config.nix
    ../../common/zram-swap.nix
    srvos.nixosModules.mixins-systemd-boot
  ];

  # Needed for Wayland/cage compositor
  hardware.graphics.enable = true;
  services.seatd.enable = true;

  # QEMU
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
