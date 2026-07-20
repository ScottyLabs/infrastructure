{
  flake.modules.nixos.btrfs =
    { pkgs, ... }:

    {
      environment.systemPackages = [ pkgs.btrbk ];

      services.btrfs.autoScrub = {
        enable = true;
        interval = "monthly";
        fileSystems = [ "/" ];
      };

      # Mount top-level btrfs for btrbk to access subvolumes
      fileSystems."/mnt/btrfs-root" = {
        device = "/dev/disk/by-partlabel/disk-main-root";
        fsType = "btrfs";
        options = [
          "subvolid=5"
          "noatime"
        ];
      };

      # Btrbk does not create snapshot directories automatically
      systemd.tmpfiles.rules = [
        "d /mnt/btrfs-root/.snapshots 0755 root root"
      ];

      services.btrbk.instances."btrbk" = {
        onCalendar = "*-*-* 03:00:00"; # after daily nix.gc at 00:00
        settings = {
          snapshot_preserve_min = "2d"; # always keep at least 2 days
          snapshot_preserve = "7d";
          volume."/mnt/btrfs-root" = {
            snapshot_dir = ".snapshots"; # Store snapshots in /.snapshots
            subvolume."@".snapshot_create = "always"; # Snapshot root
          };
        };
      };
    };
}
