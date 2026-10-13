{ grafana, ... }:
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

      systemd.tmpfiles.rules = [
        # Btrbk does not create snapshot directories automatically
        "d /mnt/btrfs-root/.snapshots 0755 root root"
        # Return emptied data chunks left by nix gc to the unallocated pool
        "w /sys/fs/btrfs/*/allocation/data/dynamic_reclaim - - - - 1"
        "w /sys/fs/btrfs/*/allocation/data/periodic_reclaim - - - - 1"
      ];

      services.btrbk.instances."btrbk" = {
        onCalendar = "*-*-* 03:00:00"; # after daily nix.gc at 00:00
        settings = {
          snapshot_preserve_min = "2d"; # always keep at least 2 days
          snapshot_preserve = "3d";
          volume."/mnt/btrfs-root" = {
            snapshot_dir = ".snapshots"; # Store snapshots in /.snapshots
            subvolume."@".snapshot_create = "always"; # Snapshot root
          };
        };
      };
    };

  scottylabs.observability.alerts.rules = [
    {
      name = "btrfs-allocation";
      source = grafana.thresholdAlert {
        name = "hosts";
        uid = "infra-btrfs-allocation";
        title = "btrfs allocation >95%";
        expr = "sum by (instance, uuid) (node_btrfs_size_bytes * node_btrfs_allocation_ratio) / sum by (instance, uuid) (node_btrfs_device_size_bytes)";
        threshold = 0.95;
        op = "gt";
        severity = "critical";
        summary = "{{ $labels.instance }} btrfs is {{ $values.A.Value | humanizePercentage }} chunk-allocated (near exhaustion, writes may fail despite free space)";
        duration = "5m";
        from = 600;
      };
    }
  ];
}
