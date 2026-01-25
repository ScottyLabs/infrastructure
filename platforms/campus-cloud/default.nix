{...}:

{
  imports = [
    ./disk-config.nix
  ];

  # VMware kernel modules for CampusCloud VMs
  boot.initrd.availableKernelModules = [ "vmw_pvscsi" "sd_mod" "sr_mod" ];

  # Enable VMware guest tools
  virtualisation.vmware.guest.enable = true;
  
  # UEFI boot for CampusCloud
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
