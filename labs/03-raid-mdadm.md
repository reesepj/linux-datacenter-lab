# Lab 03 — RAID with mdadm

> **Snapshot first.** This lab is destructive. From your KVM host, take a rollback point before you start:
> ```bash
> sudo virsh snapshot-create-as linux-lab pre-raid "before RAID lab"
> ```
> If anything goes sideways: `sudo virsh snapshot-revert linux-lab pre-raid`.

## Objectives

By the end of this module you will:

- Build a RAID1 mirror across two spare disks with `mdadm`.
- Inspect array health with `/proc/mdstat` and `mdadm --detail`.
- Put a filesystem on the array and mount it.
- **Simulate a disk failure**, then **rebuild** the array onto a replacement disk and watch it resync.
- Persist the array so it assembles automatically at boot.

## Background

RAID (Redundant Array of Independent Disks) combines several physical disks into one logical device for redundancy, performance, or both. On Linux, **software RAID** is managed by `mdadm`, which presents the array as a single block device like `/dev/md0`.

The common levels:

- **RAID0** — striping. Fast, zero redundancy. One disk dies, all data is gone.
- **RAID1** — mirroring. Every block written to both disks. Survives one disk failure. This lab.
- **RAID5** — striping with distributed parity across 3+ disks. Survives one disk failure with less capacity overhead than mirroring.

The job skill here is not "type the create command" — it is handling the **degraded** state calmly: identifying the failed member, removing it, adding the replacement, and confirming the rebuild completes. That is a real incident in any data center or NOC.

We use only the spare disks `/dev/vdb`, `/dev/vdc`, `/dev/vdd`. **Never touch `/dev/vda`.**

## Lab

### 1. Confirm the spare disks are blank

```bash
lsblk /dev/vdb /dev/vdc /dev/vdd
```

Each should be ~2G with no partitions or mountpoints. If a previous lab left signatures, wipe them (spares only):

```bash
sudo wipefs -a /dev/vdb /dev/vdc /dev/vdd
```

### 2. Create a RAID1 mirror across two disks

We mirror `/dev/vdb` and `/dev/vdc`, holding `/dev/vdd` back as the spare we will rebuild onto later.

```bash
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/vdb /dev/vdc
```

`mdadm` may warn that the disks could be part of a boot config; type `y` to continue. Expected:

```
mdadm: array /dev/md0 started.
```

### 3. Watch the initial sync

A fresh mirror syncs the two disks. Watch it live:

```bash
cat /proc/mdstat
```

Expected (resync in progress):

```
Personalities : [raid1]
md0 : active raid1 vdc[1] vdb[0]
      2094080 blocks super 1.2 [2/2] [UU]
      [=========>...........]  resync = 47.5% (...)
```

`[UU]` means both members are **U**p. Wait until the resync finishes (it is fast on 2G disks).

### 4. Inspect the array in detail

```bash
sudo mdadm --detail /dev/md0
```

Expected (trimmed):

```
        Version : 1.2
     Raid Level : raid1
   Raid Devices : 2
  Active Devices : 2
  Working Devices : 2
   Failed Devices : 0
          State : clean
    Number   Major   Minor   RaidDevice State
       0     254       16        0      active sync   /dev/vdb
       1     254       32        1      active sync   /dev/vdc
```

### 5. Put a filesystem on the array and mount it

The array is just a block device — format `/dev/md0`, not the underlying disks.

```bash
sudo mkfs.ext4 /dev/md0
sudo mkdir -p /mnt/raid
sudo mount /dev/md0 /mnt/raid
df -h /mnt/raid
```

Write a test file so you can prove the data survives a failure:

```bash
echo "raid1 survives one disk" | sudo tee /mnt/raid/canary.txt
```

### 6. Simulate a disk failure

This is the heart of the lab. Mark `/dev/vdb` as failed, then remove it — exactly what you would do when a monitoring alert flags a bad drive.

```bash
sudo mdadm --manage /dev/md0 --fail /dev/vdb
sudo mdadm --manage /dev/md0 --remove /dev/vdb
```

Expected:

```
mdadm: set /dev/vdb faulty in /dev/md0
mdadm: hot removed /dev/vdb from /dev/md0
```

Confirm the array is now **degraded** but still serving data:

```bash
cat /proc/mdstat
cat /mnt/raid/canary.txt        # still readable — that is the whole point
```

`/proc/mdstat` now shows `[2/1] [_U]` — one member down, one up.

### 7. Rebuild onto the replacement disk

Add the held-back spare `/dev/vdd` as the replacement. `mdadm` immediately starts rebuilding the mirror onto it.

```bash
sudo mdadm --manage /dev/md0 --add /dev/vdd
```

Watch the resync rebuild the data onto the new disk:

```bash
cat /proc/mdstat
```

Expected (recovery in progress):

```
md0 : active raid1 vdd[2] vdc[1]
      2094080 blocks super 1.2 [2/1] [_U]
      [=====>...............]  recovery = 28.3% (...)
```

When it finishes, the array returns to `[2/2] [UU]` with `/dev/vdc` and `/dev/vdd` as members. Verify:

```bash
sudo mdadm --detail /dev/md0
```

### 8. Persist the array config

Without a saved config, the device may come back as `/dev/md127` after reboot. Capture the array definition and update the initramfs.

```bash
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u
```

The appended line looks like:

```
ARRAY /dev/md0 metadata=1.2 name=lab:0 UUID=...
```

For mounting at boot, add it to `/etc/fstab` by UUID (do **not** add it half-built — only once the array is clean):

```bash
echo "UUID=$(sudo blkid -s UUID -o value /dev/md0) /mnt/raid ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

### 9. (Optional) RAID5 across all three disks

If you want to see parity RAID, tear down the mirror (see Cleanup) and build a RAID5 across the three spares. RAID5 needs at least 3 devices and survives one failure while keeping more usable capacity than a mirror:

```bash
sudo mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/vdb /dev/vdc /dev/vdd
cat /proc/mdstat
```

The same `--fail` / `--remove` / `--add` workflow applies.

## Verification

- `cat /proc/mdstat` shows `md0` with `[UU]` (both members up) after the rebuild.
- `sudo mdadm --detail /dev/md0` reports `State : clean` and `Failed Devices : 0`.
- `cat /mnt/raid/canary.txt` still prints your test line — data survived the simulated failure.
- `grep ARRAY /etc/mdadm/mdadm.conf` shows your persisted array line.

## Why it matters

Disks fail — that is a certainty, not a risk. In data center and NOC roles, the value you add is not knowing that RAID exists; it is responding to a degraded array correctly and quickly: confirming the array is still serving data, identifying the failed member, swapping it, and verifying the rebuild completed before you close the ticket. Practicing the fail-remove-add-resync loop here builds the muscle memory for doing it on production hardware under pressure.

## Cleanup

Unmount, stop the array, and zero the superblocks so the disks are blank for the next lab. Remove the lines you added to `/etc/fstab` and `/etc/mdadm/mdadm.conf` as well.

```bash
sudo umount /mnt/raid
sudo mdadm --stop /dev/md0
sudo mdadm --zero-superblock /dev/vdb /dev/vdc /dev/vdd
sudo sed -i '/md0/d' /etc/fstab
sudo sed -i '/ARRAY \/dev\/md0/d' /etc/mdadm/mdadm.conf
lsblk        # vdb/vdc/vdd should be blank again
```

Or simply roll back to your snapshot: `sudo virsh snapshot-revert linux-lab pre-raid`.

**Write a short runbook** of what you did: the create command, how you simulated and recovered the failure, and how you persisted the config — and what tripped you up.
