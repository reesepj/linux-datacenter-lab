# Lab 02 — Storage: Disks, Partitions, Filesystems

> **Module format.** Every lab uses the same shape: Objectives, Background, Lab, Verification, Why it matters, Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Identify disks and partitions with `lsblk` and `blkid`.
- Partition a spare disk with `parted` (and `gdisk` as the interactive alternative).
- Create `ext4` and `xfs` filesystems and mount them.
- Make a mount survive reboot via `/etc/fstab`, then prove it with `mount -a`.
- Measure space with `df` and `du`, and unmount and clean up safely.

## Background

A raw disk is just a block device (`/dev/vdb`). To store files you give it a *partition table* (GPT here), carve one or more *partitions*, lay a *filesystem* on a partition, then *mount* that filesystem onto a directory so the OS can use it. `ext4` is the dependable general-purpose default; `xfs` excels at large files and parallel I/O and is common on servers. UUIDs are stable identifiers for filesystems — you reference them in `/etc/fstab` instead of device names, because `/dev/vdX` letters can shift between boots.

> **One rule, always:** every command in this lab targets a **spare** disk (`/dev/vdb`, optionally `/dev/vdc`). Never `/dev/vda` — that is the OS disk. Writing a partition table or filesystem is destructive; on a spare disk that is fine, on the OS disk it ends the VM.

**Snapshot first.** From your KVM host, before you start:

```bash
sudo virsh snapshot-create-as linux-lab pre-lab02 "before storage lab"
# to undo everything later:
sudo virsh snapshot-revert linux-lab pre-lab02
```

## Lab

### 1. Identify the disks

```bash
lsblk                            # tree of disks and partitions
lsblk -f                         # add filesystem type, label, UUID, mountpoint
sudo fdisk -l /dev/vdb           # confirm vdb is ~2G and currently empty
```

Expected: `vdb`, `vdc`, `vdd` appear as ~2G disks with **no** child partitions and **no** mountpoints. Confirm before continuing.

### 2. Partition /dev/vdb with parted (scriptable)

```bash
# Create a GPT label and one partition spanning the whole disk:
sudo parted -s /dev/vdb mklabel gpt
sudo parted -s /dev/vdb mkpart primary 1MiB 100%
sudo parted -s /dev/vdb print    # verify the new partition
sudo partprobe /dev/vdb          # make the kernel re-read the table
lsblk /dev/vdb                   # you should now see vdb1
```

Expected: `parted print` shows `Partition Table: gpt` and one partition; `lsblk` shows `vdb1`.

### 3. (Reference) The same with gdisk, interactively

You do **not** need to run this if step 2 worked — it is the interactive alternative for when you prefer a guided tool. To try it, use spare disk `/dev/vdc`:

```bash
sudo gdisk /dev/vdc
# At the prompts, type:
#   o   -> create a new empty GPT (answer Y)
#   n   -> new partition; accept defaults for number, start, end; type 8300 (Linux)
#   p   -> print to review
#   w   -> write to disk (answer Y)
sudo partprobe /dev/vdc
lsblk /dev/vdc                   # shows vdc1
```

### 4. Create filesystems

```bash
# ext4 on the vdb partition:
sudo mkfs.ext4 -L data-ext4 /dev/vdb1

# xfs on the vdc partition (if you made one in step 3):
sudo mkfs.xfs -L data-xfs /dev/vdc1

lsblk -f                         # confirm TYPE shows ext4 / xfs and the labels
```

Expected: `mkfs.ext4` prints `Creating filesystem ... done`; `lsblk -f` shows `ext4` on `vdb1` (and `xfs` on `vdc1`).

### 5. Mount and use them

```bash
sudo mkdir -p /mnt/data1 /mnt/data2
sudo mount /dev/vdb1 /mnt/data1
sudo mount /dev/vdc1 /mnt/data2   # skip if you did not create vdc1

mount | grep /mnt/data            # confirm both are mounted
echo "hello from ext4" | sudo tee /mnt/data1/test.txt
cat /mnt/data1/test.txt
```

Expected: `mount | grep /mnt/data` lists `/dev/vdb1 on /mnt/data1 type ext4`.

### 6. Get UUIDs and make the mount persistent

```bash
sudo blkid /dev/vdb1             # note the UUID="..."

# Back up fstab before editing it:
sudo cp /etc/fstab /etc/fstab.bak

# Append a persistent entry using the UUID (nofail keeps a bad entry from
# blocking boot while you are learning):
echo "UUID=$(sudo blkid -s UUID -o value /dev/vdb1)  /mnt/data1  ext4  defaults,nofail  0  2" | sudo tee -a /etc/fstab

tail -n 2 /etc/fstab             # review what you just added
```

Expected: the new line shows your real UUID, `/mnt/data1`, `ext4`, `defaults,nofail`.

### 7. Test fstab without rebooting

```bash
sudo umount /mnt/data1           # unmount it
mount | grep data1               # confirms it is gone
sudo mount -a                    # mount everything in fstab
mount | grep data1               # it came back, proving fstab is correct
```

Expected: after `mount -a`, `/mnt/data1` is mounted again. If `mount -a` errors, your fstab line is wrong — fix it now, while you can, not at next boot.

### 8. Inspect usage with df and du

```bash
df -h                            # free space per mounted filesystem
df -h /mnt/data1                 # just this one
df -i /mnt/data1                 # inode usage (you can run out of these too)

# Generate some data, then measure it:
sudo dd if=/dev/zero of=/mnt/data1/blob bs=1M count=200 status=progress
du -sh /mnt/data1                # total size of the directory
du -h --max-depth=1 /mnt/data1   # per-entry breakdown
ncdu /mnt/data1                  # interactive disk usage (q to quit)
```

Expected: `du -sh /mnt/data1` reports roughly `200M` after the `dd`.

## Verification

- `lsblk -f` shows `ext4` (and `xfs`) filesystems with your labels on the spare partitions.
- `mount -a` re-mounts `/mnt/data1` with no errors after you unmounted it.
- `blkid /dev/vdb1` prints a UUID that matches the one in `/etc/fstab`.
- `df -h /mnt/data1` shows the mounted filesystem with used/available space.

## Why it matters

Provisioning storage is daily work in data center and operations roles: a new server needs disks partitioned and formatted, a host runs out of space and you trace it with `df`/`du`, or a box fails to boot because someone wrote a bad `/etc/fstab` line. Knowing UUID-based, `nofail`-guarded fstab entries — and testing them with `mount -a` before trusting a reboot — is exactly the discipline that prevents 2 a.m. outages.

## Cleanup

```bash
# Unmount the practice filesystems:
sudo umount /mnt/data1 /mnt/data2 2>/dev/null

# Restore fstab to its pre-lab state:
sudo cp /etc/fstab.bak /etc/fstab
sudo mount -a                    # confirm the restored fstab is clean

# Remove the mountpoints:
sudo rmdir /mnt/data1 /mnt/data2 2>/dev/null

# (Optional) wipe the partition tables so the spares are blank for the next lab:
sudo wipefs -a /dev/vdb /dev/vdc
lsblk                            # vdb/vdc should show no partitions again
```

Write a short runbook of what you did and how you fixed anything that went wrong — your future self under pressure will thank you.
