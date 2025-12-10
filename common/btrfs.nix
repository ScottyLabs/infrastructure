{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.btrbk ];

  # Mount top-level btrfs for btrbk to access subvolumes
  fileSystems."/mnt/btrfs-root" = {
    device = "/dev/disk/by-partlabel/disk-main-root";
    fsType = "btrfs";
    options = [ "subvolid=5" "noatime" ];
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  services.btrbk.instances."btrbk" = {
    onCalendar = "daily";                    # Run once per day
    settings = {
      snapshot_preserve_min = "2d";          # Always keep at least 2 days
      snapshot_preserve = "7d 4w";           # Keep 7 daily + 4 weekly snapshots
      volume."/mnt/btrfs-root" = {
        snapshot_dir = ".snapshots";         # Store snapshots in /.snapshots
        subvolume."@".snapshot_create = "always";      # Snapshot root
        subvolume."@home".snapshot_create = "always";  # Snapshot home
      };
    };
  };
}
