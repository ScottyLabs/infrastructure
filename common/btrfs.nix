{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.btrbk ];

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
      volume."/" = {
        snapshot_dir = ".snapshots";         # Store snapshots in /.snapshots
        subvolume."@".snapshot_create = "always";      # Snapshot root
        subvolume."@home".snapshot_create = "always";  # Snapshot home
      };
    };
  };
}
