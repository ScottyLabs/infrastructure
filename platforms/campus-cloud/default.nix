{...}:

{
  imports = [
    ./disk-config.nix
  ];

  # VMware kernel modules for CampusCloud VMs
  boot.initrd.availableKernelModules = [ "vmw_pvscsi" "sd_mod" "sr_mod" ];

  # Enable VMware guest tools
  virtualisation.vmware.guest.enable = true;
}
