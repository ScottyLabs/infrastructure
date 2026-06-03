# Expanding a Campus Cloud VM disk

Campus Cloud disks are resized in **vSphere** (no ticket to Computing Services required for a larger virtual disk). NixOS on these hosts uses **disko** with a btrfs root on the last GPT partition (`disk-main-root`), sized to **100%** of the virtual disk at install time. After the VMDK grows, extend the partition and btrfs inside the guest.

**Reference sizes:** infra-01 and deploy-01 are typically expanded to **120 GB** so the Nix store and comin sub-profiles have headroom. New VMs still default to 40 GB in [Purchasing a VM](./01-purchasing-vm.md) unless you request more at purchase time.

## 1. Grow the virtual disk (vSphere)

1. Open [Citrix Workspace](https://apps.cmu.edu/) → **Campus Cloud vSphere Client**.
2. Log in with your Andrew ID.
3. Locate the VM (e.g. `deploy-01`; the vSphere inventory name may still be `prod-01`).
4. **Actions → Edit Settings** (or right-click → **Edit Settings**).
5. Expand **Hard disk** and set **Capacity** to the new size (e.g. **120 GB**).
6. Click **OK**. The change is online for Linux guests; no power-off is required.

## 2. Grow the partition and btrfs (on the VM)

SSH in over **Tailscale** (or use the vSphere console if the host has no SSH). Run:

```bash
# Confirm disk and root partition (usually sda, root is the large partition after ESP + swap)
lsblk
sudo findmnt -no SOURCE /

# Rescan the disk (VMware SCSI; adjust /dev/sda if your disk node differs)
echo 1 | sudo tee /sys/block/sda/device/rescan
sudo partprobe /dev/sda

# Grow the root partition — replace 3 with the root partition NUMBER from lsblk
sudo growpart /dev/sda 3

# Grow btrfs on /
sudo btrfs filesystem resize max /

# Verify
df -h /
```

If `growpart` is missing, use a one-off nix shell:

```bash
nix shell nixpkgs#gptfdisk nixpkgs#util-linux -c bash
# then growpart as above
```

**By partlabel** (matches `common/btrfs.nix`):

```bash
ROOT_PART=$(readlink -f /dev/disk/by-partlabel/disk-main-root)
DISK=/dev/$(lsblk -no pkname "$ROOT_PART")
PARTNUM=$(lsblk -no PARTN "$ROOT_PART")
echo 1 | sudo tee "/sys/block/$(basename "$DISK")/device/rescan"
sudo partprobe "$DISK"
sudo growpart "$DISK" "$PARTNUM"
sudo btrfs filesystem resize max /
df -h /
```

No NixOS rebuild is required for a size-only change. **disko** in the flake does not re-partition an existing disk on `switch`; it only defines layout at install.

## 3. Optional: btrfs balance

If the volume was very full, run a balance during a quiet window:

```bash
sudo btrfs balance start -dusage=50 -musage=50 /
```

## 4. Alerts

Root filesystem usage is monitored by Grafana rule `infra-disk-full` in the [observability](https://codeberg.org/ScottyLabs/observability) repo (`alerts/rules/infra/disk-full.yaml`). After changing that repo, push to `main` so the flake input on infra-01 updates (same webhook flow as other repos).

## Troubleshooting

| Problem | What to check |
|---------|----------------|
| `growpart` says NOCHANGE | VMDK size in vSphere; run `rescan` + `partprobe` again |
| `resize max` fails | Partition grown first? `lsblk` should show larger partition before btrfs resize |
| Host unreachable | See [troubleshooting](../troubleshooting.md); use vSphere console |
