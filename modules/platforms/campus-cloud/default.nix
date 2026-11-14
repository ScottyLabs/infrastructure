{ config, ... }:
{
  flake.modules.nixos.campus-cloud =
    { inputs, ... }:
    {
      imports = [
        config.flake.modules.nixos.campus-cloud-disk
        inputs.srvos.nixosModules.mixins-systemd-boot
      ];

      # VMware kernel modules for CampusCloud VMs
      boot.initrd.availableKernelModules = [
        "vmw_pvscsi"
        "sd_mod"
        "sr_mod"
      ];

      # Enable VMware guest tools
      virtualisation.vmware.guest = {
        enable = true;
        headless = true;
      };

      # CampusCloud VMs have no serial port
      srvos.boot.consoles = [ "tty0" ];
      systemd.services."serial-getty@ttyS0".enable = false;
    };
}
