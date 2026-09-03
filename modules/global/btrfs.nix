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
    {
      name = "disk-usage-warning";
      source = grafana.thresholdAlert {
        name = "hosts";
        uid = "infra-disk-usage-warning";
        title = "disk usage >75%";
        expr = "1 - (node_filesystem_avail_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"})";
        threshold = 0.75;
        op = "gt";
        severity = "warning";
        summary = "{{ $labels.instance }} / is {{ $values.A.Value | humanizePercentage }} full - investigate before hitting btrfs allocation limit";
        duration = "10m";
        from = 600;
      };
    }
  ];
}
