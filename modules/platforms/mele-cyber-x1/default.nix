{ config, ... }:
{
  flake.modules.nixos.mele-cyber-x1 =
    { inputs, ... }:
    {
      imports = [
        config.flake.modules.nixos.mele-cyber-x1-disk
        config.flake.modules.nixos.zram-swap
        inputs.srvos.nixosModules.mixins-systemd-boot
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
    };
}
