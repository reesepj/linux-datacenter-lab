# Lab 00 — Getting Started

> **Module format.** Every lab uses the same shape: Objectives, Background, Lab, Verification, Why it matters, Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Have a running lab VM and know how to connect to it.
- Understand the lab conventions and the one safety rule that keeps you out of trouble.
- Know how to snapshot and roll back so every later lab is risk-free.

## Background

This course runs inside a disposable Debian virtual machine. You will deliberately break storage, services, and networking, then fix them. Because it is disposable, mistakes cost nothing — that is the point. Operations skill is built by doing the recovery, not by reading about it.

The VM has four disks:

- `/dev/vda` — the operating system disk. **Leave it alone.**
- `/dev/vdb`, `/dev/vdc`, `/dev/vdd` — blank spare disks. **All storage labs happen here.**

## Lab

### 1. Build the VM (on your KVM host)

```bash
./provisioning/build-lab-vm.sh
```

This creates the VM, attaches the three spare disks, and installs the toolset.

### 2. Connect

```bash
./provisioning/lab-connect.sh
```

Default credentials: user `labuser`, password `changeme`, with passwordless sudo. Change the password now:

```bash
passwd
```

### 3. Survey the environment

```bash
uname -a                 # kernel and architecture
cat /etc/os-release      # distribution
lsblk                    # disks: confirm vda + vdb/vdc/vdd
df -h                    # mounted filesystems and free space
free -h                  # memory
ip -brief addr           # network interfaces
sudo whoami              # confirm sudo works (prints: root)
```

### 4. Learn to snapshot (do this before every risky lab)

```bash
# from the KVM host, not inside the VM:
sudo virsh snapshot-create-as linux-lab pre-lab "before a risky lab"
# ...later, to undo everything:
sudo virsh snapshot-revert linux-lab pre-lab
```

## Verification

- `lsblk` shows one ~40G disk (`vda`) and three small spare disks (`vdb`, `vdc`, `vdd`).
- `sudo whoami` prints `root`.
- You can list snapshots: `sudo virsh snapshot-list linux-lab`.

## Why it matters

Every shift in a data center or NOC starts with situational awareness: what hardware is in front of you, what state it is in, and what you are allowed to touch. Building the reflex to survey a system (`lsblk`, `df`, `ip`, `uname`) before acting — and to create a rollback point before risky work — is foundational to doing the job safely.

## Cleanup

Nothing to clean up. Take a `clean-baseline` snapshot now so you can always return to a fresh box, then continue to **Lab 01**.

```bash
sudo virsh snapshot-create-as linux-lab clean-baseline "fresh lab"
```
