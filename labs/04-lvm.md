# Lab 04 — LVM

> **Snapshot first.** This lab is destructive. From your KVM host:
> ```bash
> sudo virsh snapshot-create-as linux-lab pre-lvm "before LVM lab"
> ```
> Roll back with: `sudo virsh snapshot-revert linux-lab pre-lvm`.

## Objectives

By the end of this module you will:

- Build the full LVM stack: physical volumes, a volume group, and a logical volume.
- Put a filesystem on a logical volume and mount it.
- **Grow** the storage online by adding a disk and extending the volume and filesystem.
- Take an **LVM snapshot**, prove it works, and restore from it.

## Background

LVM (Logical Volume Manager) sits between your physical disks and your filesystems, so storage stops being a fixed map of "one partition, one disk." The mental model is three layers:

- **PV (Physical Volume)** — a whole disk or partition you hand to LVM (`/dev/vdb`).
- **VG (Volume Group)** — a pool of capacity made by combining one or more PVs. Think of it as one big bucket of blocks.
- **LV (Logical Volume)** — a slice carved out of the VG that you format and mount, like a flexible partition.

```
[ /dev/vdb ] [ /dev/vdc ]   <- PVs
        \       /
       [ vg_data ]           <- VG (the pool)
        /       \
  [ lv_app ]  [ lv_logs ]    <- LVs (carved from the pool)
```

The payoff: you can grow an LV by adding a disk to the VG and extending — no repartition, no downtime, no copying data to a bigger disk. That flexibility is why LVM is standard on servers.

We use only the spare disks `/dev/vdb`, `/dev/vdc`, `/dev/vdd`. **Never touch `/dev/vda`.**

## Lab

### 1. Confirm the spares are blank

```bash
lsblk /dev/vdb /dev/vdc /dev/vdd
```

If a previous lab left signatures (e.g. RAID superblocks), clear them on the spares:

```bash
sudo wipefs -a /dev/vdb /dev/vdc /dev/vdd
```

### 2. Create physical volumes

Initialize two disks as PVs so LVM can use them.

```bash
sudo pvcreate /dev/vdb /dev/vdc
sudo pvs
```

Expected:

```
  PV         VG     Fmt  Attr PSize  PFree
  /dev/vdb          lvm2 ---  2.00g  2.00g
  /dev/vdc          lvm2 ---  2.00g  2.00g
```

### 3. Create a volume group

Pool the two PVs into one VG named `vg_data` (~4G total).

```bash
sudo vgcreate vg_data /dev/vdb /dev/vdc
sudo vgs
```

Expected:

```
  VG       #PV #LV #SN Attr   VSize  VFree
  vg_data    2   0   0 wz--n- 3.99g  3.99g
```

### 4. Create a logical volume

Carve a 2G logical volume named `lv_app` out of the pool.

```bash
sudo lvcreate -n lv_app -L 2G vg_data
sudo lvs
```

The LV appears at `/dev/vg_data/lv_app`.

### 5. Format and mount it

```bash
sudo mkfs.ext4 /dev/vg_data/lv_app
sudo mkdir -p /mnt/lvm
sudo mount /dev/vg_data/lv_app /mnt/lvm
df -h /mnt/lvm
```

Drop a test file so you can track it through the grow and snapshot steps:

```bash
echo "lvm baseline" | sudo tee /mnt/lvm/data.txt
```

### 6. Grow the storage by adding a disk

This is LVM's headline feature. Add the third spare to the pool, extend the LV into the new space, then grow the filesystem to fill it — all while it stays mounted.

```bash
# Add /dev/vdd to the pool as a new PV inside the VG:
sudo vgextend vg_data /dev/vdd

# Extend the LV to use all free space in the VG:
sudo lvextend -l +100%FREE /dev/vg_data/lv_app

# Grow the filesystem to match (ext4 grows online):
sudo resize2fs /dev/vg_data/lv_app
df -h /mnt/lvm        # capacity jumped, mount never dropped
```

> **XFS note.** If the LV held an XFS filesystem instead of ext4, you would grow it with `sudo xfs_growfs /mnt/lvm` (XFS resizes by mountpoint, not device, and only grows — never shrinks).

### 7. Take an LVM snapshot

A snapshot is a point-in-time copy of the LV that uses copy-on-write — it only stores blocks that change after the snapshot is taken, so it is cheap to create.

```bash
sudo lvcreate -s -n lv_app_snap -L 512M /dev/vg_data/lv_app
sudo lvs
```

The `-s` flag makes it a snapshot of `lv_app`; the `-L 512M` is the space reserved for changed blocks.

### 8. Change data, then restore from the snapshot

Now simulate a bad change after the snapshot, then roll the LV back to the snapshot state.

```bash
# Corrupt/modify the live data:
echo "OOPS bad change" | sudo tee /mnt/lvm/data.txt
cat /mnt/lvm/data.txt              # shows the bad change

# Restore: merging requires the LV to be unmounted.
sudo umount /mnt/lvm
sudo lvconvert --merge /dev/vg_data/lv_app_snap

# Remount and confirm the original content is back:
sudo mount /dev/vg_data/lv_app /mnt/lvm
cat /mnt/lvm/data.txt              # back to "lvm baseline"
```

`lvconvert --merge` rolls the LV back to the snapshot and then automatically removes the snapshot once merged.

## Verification

- `sudo pvs` lists `/dev/vdb`, `/dev/vdc`, and `/dev/vdd` belonging to `vg_data`.
- `sudo vgs` shows `vg_data` at ~6G after the `vgextend`.
- `df -h /mnt/lvm` shows the larger size after the extend+resize.
- `cat /mnt/lvm/data.txt` reads `lvm baseline` after the snapshot restore.

## Why it matters

Storage demand never shrinks, and "we are out of disk" should never mean downtime. LVM is how operations teams add capacity to a running server, isolate workloads onto separate logical volumes, and take fast restore points before risky changes. Knowing the PV/VG/LV model — and being able to grow a filesystem online or roll one back from a snapshot — is everyday infrastructure work in data center, NOC, and sysadmin roles.

## Cleanup

Unmount and tear down the stack so the spares are blank for the next lab.

```bash
sudo umount /mnt/lvm
sudo lvremove -y /dev/vg_data/lv_app
sudo vgremove -y vg_data
sudo pvremove /dev/vdb /dev/vdc /dev/vdd
lsblk        # vdb/vdc/vdd should be blank again
```

Or roll back to your snapshot: `sudo virsh snapshot-revert linux-lab pre-lvm`.

**Write a short runbook** of what you did: the pvcreate/vgcreate/lvcreate chain, how you grew the volume online, and how you took and restored a snapshot — plus anything that surprised you.
