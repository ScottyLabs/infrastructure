{ config, ... }:
{
  flake.modules.nixos.occ =
    { inputs, pkgs, ... }:
    {
      imports = [
        config.flake.modules.nixos.occ-disk
        inputs.srvos.nixosModules.mixins-systemd-boot
      ];

      # Incus VMs boot from virtio-scsi
      boot.initrd.availableKernelModules = [
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
      ];

      # Lets incus exec and incus file reach the VM
      virtualisation.incus.agent.enable = true;

      boot.kernelParams = [
        "console=${if pkgs.stdenv.hostPlatform.isx86 then "ttyS0" else "ttyAMA0"}"
      ];

      # Applies just the network config from Incus
      services.cloud-init = {
        enable = true;
        network.enable = true;
        settings = {
          preserve_hostname = true;
          cloud_init_modules = [ ];
          cloud_config_modules = [ ];
          cloud_final_modules = [ ];
        };
      };
    };
}
