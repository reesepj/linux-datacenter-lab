# Lab 09 — Security Basics

> **Module format.** Every lab uses the same shape: Objectives, Background, Lab, Verification, Why it matters, Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Generate an SSH key pair and log in with key-based authentication.
- Harden `sshd_config` safely: disable root login and password auth — **only after** verifying key login works.
- Manage users and `sudo` access with least privilege using `/etc/sudoers.d`.
- Audit file permissions: find SUID binaries and world-writable files.
- Apply system updates and enable automatic security updates.
- Understand what `fail2ban` does and why it matters.

## Background

A data center host is a target the moment it has an IP. The cheapest, highest-impact wins are: key-only SSH, no root login, a patched system, and least-privilege accounts. None of this is exotic — it is the baseline every NOC and ops team is expected to enforce.

The single most common way to lock yourself out of a remote box is editing `sshd_config` and reloading the service while your only working login is the one you just broke. The rule of this lab: **keep your current session open, test the new login in a *second* session, and only then change the old behavior.**

**Snapshot first** (from the KVM host, not inside the VM):

```bash
sudo virsh snapshot-create-as linux-lab pre-lab09 "before security hardening"
```

If you lock yourself out, roll back and try again:

```bash
sudo virsh snapshot-revert linux-lab pre-lab09
```

## Lab

### 1. Generate an SSH key pair

Run this on your **client** machine (the laptop/host you SSH *from*), not on the lab VM. If you only have the VM, run it there to learn the mechanics.

```bash
ssh-keygen -t ed25519 -C "labuser key" -f ~/.ssh/lab_ed25519
# Expected: creates ~/.ssh/lab_ed25519 (private) and lab_ed25519.pub (public)
```

Never share or copy the private key. Only the `.pub` file leaves your machine.

### 2. Install the public key on the lab VM

```bash
ssh-copy-id -i ~/.ssh/lab_ed25519.pub labuser@<lab-vm-ip>
# Or do it manually if ssh-copy-id is unavailable:
#   cat ~/.ssh/lab_ed25519.pub | ssh labuser@<lab-vm-ip> \
#     'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

Confirm the file on the VM:

```bash
ls -l ~/.ssh/authorized_keys    # must be -rw------- (600)
cat ~/.ssh/authorized_keys      # your ed25519 key appears here
```

### 3. Test key login in a SECOND session — before changing anything

**Leave your current shell open.** Open a new terminal and connect with the key:

```bash
ssh -i ~/.ssh/lab_ed25519 labuser@<lab-vm-ip>
# Expected: you land at the prompt without being asked for a password
```

If that worked, continue. If it prompted for a password or failed, **stop and fix the key** before touching `sshd_config`.

### 4. Harden sshd_config

Back up first, then edit:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo vim /etc/ssh/sshd_config
```

Set these directives (uncomment or add them):

```
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Validate the syntax before reloading — this catches typos that would break the service:

```bash
sudo sshd -t        # no output = config is valid
```

Allow the new port through any host firewall if one is active, then reload:

```bash
sudo systemctl reload ssh
```

### 5. Verify the hardened login in yet another fresh session

Keep the working session open. In a new terminal, connect on the new port with the key:

```bash
ssh -i ~/.ssh/lab_ed25519 -p 2222 labuser@<lab-vm-ip>
# Expected: logs in with the key, on port 2222
```

Confirm password auth and root login are refused:

```bash
ssh -p 2222 -o PreferredAuthentications=password -o PubkeyAuthentication=no labuser@<lab-vm-ip>
# Expected: "Permission denied (publickey)."
```

Only once all of this works should you close your original session.

### 6. Create a user with least-privilege sudo

```bash
sudo adduser opsuser                      # set a password when prompted
sudo usermod -aG sudo opsuser             # full sudo group membership (broad)
```

For least privilege, grant only what a role needs instead of full sudo. Use a drop-in file and validate it with `visudo`:

```bash
sudo visudo -f /etc/sudoers.d/opsuser
```

Add a narrowly scoped rule, for example allowing only service control:

```
opsuser ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl status nginx
```

`visudo` refuses to save a file with syntax errors, which is exactly why you never edit sudoers with a plain editor. Verify:

```bash
sudo -l -U opsuser     # lists only the commands opsuser may run as root
```

### 7. Audit file permissions

Find SUID binaries (run with the owner's privileges — a classic privilege-escalation surface):

```bash
sudo find / -xdev -perm -4000 -type f 2>/dev/null
# Expected: a short list like /usr/bin/sudo, /usr/bin/passwd, /usr/bin/mount ...
```

Find world-writable files (anyone can modify them — almost always a mistake):

```bash
sudo find / -xdev -type f -perm -0002 -not -path '/proc/*' 2>/dev/null
# Expected: ideally empty. Investigate anything that appears.
```

Fix a world-writable file by tightening it:

```bash
# example only — apply to a real offender you find:
sudo chmod o-w /path/to/file
```

### 8. Patch the system

```bash
sudo apt update
sudo apt upgrade -y
sudo apt --purge autoremove -y    # drop orphaned packages
```

Enable automatic security updates so the box stays patched without manual effort:

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades   # choose "Yes"
systemctl status unattended-upgrades --no-pager
```

### 9. fail2ban (concept + quick install)

`fail2ban` watches log files (like the SSH auth log) and temporarily bans IPs that fail to authenticate too many times, blunting brute-force attacks. Install and check it:

```bash
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
# Expected: shows the sshd jail with a count of failed/banned IPs
```

## Verification

- A second/third SSH session logs in with the key on port `2222` without a password.
- `ssh` with password auth is refused: `Permission denied (publickey)`.
- `sudo sshd -t` returns no output (valid config).
- `sudo -l -U opsuser` lists only the narrowly scoped commands.
- `sudo find / -xdev -type f -perm -0002 2>/dev/null` (excluding `/proc`) returns nothing unexpected.
- `systemctl status unattended-upgrades` and `fail2ban-client status sshd` both report active.

## Why it matters

Hardening SSH, enforcing least privilege, auditing permissions, and keeping a box patched are the table-stakes security controls every operations and NOC role is expected to apply and verify. Just as important is the discipline shown here: change remote-access settings cautiously, test in a separate session, and validate config before reloading — the difference between a routine change and a midnight lockout incident.

## Cleanup

Revert SSH to defaults if you want a clean box for the next lab, and remove the practice user:

```bash
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo sshd -t && sudo systemctl reload ssh
sudo deluser --remove-home opsuser
sudo rm -f /etc/sudoers.d/opsuser
```

Or simply roll back to your snapshot:

```bash
sudo virsh snapshot-revert linux-lab pre-lab09
```

Write a short runbook: what you changed in `sshd_config`, how you confirmed key login before disabling passwords, and how you would recover if locked out.
