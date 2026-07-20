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
      virtualisation.vmware.guest.enable = true;
    };
}
