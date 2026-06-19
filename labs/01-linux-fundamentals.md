# Lab 01 — Linux Fundamentals

> **Module format.** Every lab uses the same shape: Objectives, Background, Lab, Verification, Why it matters, Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Know the Linux filesystem hierarchy and what lives where (`/etc`, `/var`, `/proc`, and friends).
- Move around and inspect a system fluently with `ls`, `cd`, `find`, `less`, `grep`, `cat`, `head`, and `tail`.
- Read and change ownership and permissions, and understand users and groups.
- List, inspect, and signal processes, and preview `systemctl`.
- Install and query software with `apt`.

## Background

Everything in Linux is a file, and those files live in a predictable tree rooted at `/`. Configuration is in `/etc`, variable data (logs, spools, databases) in `/var`, the kernel's live view of the system in `/proc`, and devices in `/dev`. Operations work is mostly *reading state* (where is the config, what is in the log, who owns this) and *making small, deliberate changes*. The tools below are the ones you reach for hundreds of times a day, so building muscle memory now pays off in every later lab.

Permissions answer "who can do what" with three classes — owner, group, other — each granted read (`r`), write (`w`), execute (`x`). Processes are running programs; you find the misbehaving one, then stop it. `apt` is Debian's package manager and your front door to installing tools.

## Lab

### 1. Walk the filesystem hierarchy

```bash
ls -l /                  # top-level directories
ls /etc | head           # system-wide configuration files
ls /var/log              # logs live here; you will read these constantly
cat /proc/cpuinfo | head # kernel's live view of the CPU
cat /proc/meminfo | head # and memory
ls /home                 # user home directories
```

Expected: `/` lists `bin etc home proc var ...`; `/var/log` shows files like `syslog`, `auth.log`.

### 2. Navigate and inspect

```bash
cd /etc
pwd                      # /etc
ls -la                   # long listing, including hidden dotfiles
less os-release          # page through a file (press q to quit)
cat hostname             # print a short file
head -n 5 passwd         # first 5 lines
tail -n 5 passwd         # last 5 lines
cd                       # back to your home directory
```

### 3. Search the system

```bash
# Find config files by name (suppress permission-denied noise):
sudo find /etc -name "*.conf" -type f | head

# Search inside files for a pattern:
grep -i "root" /etc/passwd
grep -rn "listen" /etc/nginx 2>/dev/null | head

# Combine: who logged in via sshd recently?
sudo grep "sshd" /var/log/auth.log | tail -n 5
```

Expected: `grep -i root /etc/passwd` prints the line `root:x:0:0:root:/root:/bin/bash`.

### 4. Users, groups, and identity

```bash
id                       # your uid, gid, and group memberships
whoami
groups
getent passwd labuser    # your account entry
tail -n 3 /etc/passwd    # last few accounts (format: name:x:uid:gid:gecos:home:shell)
tail -n 3 /etc/group     # group definitions
```

Expected: `id` prints something like `uid=1000(labuser) gid=1000(labuser) groups=1000(labuser),27(sudo)`.

### 5. Permissions and ownership

```bash
mkdir -p ~/lab01 && cd ~/lab01
echo "secret notes" > notes.txt
ls -l notes.txt                  # note the rw-r--r-- bits

chmod 600 notes.txt              # owner read/write only
ls -l notes.txt                  # now -rw-------

chmod u+x notes.txt              # add execute for owner (symbolic mode)
ls -l notes.txt

# Ownership changes need sudo. Create a file root owns, then give it back:
sudo touch rootfile && ls -l rootfile
sudo chown labuser:labuser rootfile
ls -l rootfile                   # now owned by you
```

Expected: after `chmod 600`, the mode column reads `-rw-------`.

### 6. Processes

```bash
ps aux | head                    # snapshot of running processes
ps aux | grep nginx              # find a specific process
top -b -n 1 | head -n 12         # one batch sample of live system load (q to quit interactive top)

# Start a throwaway background process, find it, and stop it:
sleep 600 &
jobs                             # shows the backgrounded sleep
pgrep -a sleep                   # its PID and command line
kill %1                          # stop it by job number (or: kill <PID>)
```

Expected: `pgrep -a sleep` prints a PID followed by `sleep 600`; after `kill`, `jobs` shows it done.

### 7. Preview systemctl (services)

```bash
systemctl --version | head -n 1
systemctl status ssh --no-pager | head -n 8   # is SSH running?
systemctl list-units --type=service --state=running --no-pager | head
```

Expected: `systemctl status ssh` shows `Active: active (running)`. You will manage services in depth in Lab 05.

### 8. Package management with apt

```bash
sudo apt update                  # refresh the package index
apt list --upgradable 2>/dev/null | head
apt search ncdu | head           # find a package
apt show htop | head -n 12       # metadata: version, size, description
sudo apt install -y tree         # install (tree is small and handy)
tree -L 1 /etc | head            # use what you installed
```

Expected: `apt show htop` prints `Package: htop` with a `Version:` line; `tree -L 1 /etc` draws a one-level tree.

### 9. Core text tools together

```bash
# Count accounts with a real login shell, ranked:
grep -v "/usr/sbin/nologin" /etc/passwd | grep -v "/bin/false" | wc -l

# Pull the shell field (7th, ":"-delimited) and tally usage:
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
```

Expected: `uniq -c | sort -rn` prints a count beside each shell, most common first.

## Verification

- `id` shows your uid/gid and confirms `sudo` group membership.
- `ls -l ~/lab01/notes.txt` reflects the permission changes you made (`-rw-------` plus your `u+x`).
- `pgrep sleep` returns nothing after you killed the background job.
- `tree --version` runs, proving the `apt install` succeeded.
- `systemctl status ssh` shows `active (running)`.

## Why it matters

Reading a system before changing it is the core operations reflex: where the config lives, what the log says, who owns the file, which process is pegging the CPU. Technicians, NOC, and sysadmin roles live in exactly these commands — diagnosing from `grep` over a log, sizing a problem from `top`, fixing access with `chmod`/`chown`, and pulling a tool with `apt`. Fluency here is the difference between a five-minute fix and a stalled ticket.

## Cleanup

```bash
cd ~ && rm -rf ~/lab01
# Optionally remove the package you installed for practice:
sudo apt remove -y tree
```

Write a short runbook of what you did and how you fixed anything that went wrong — your future self under pressure will thank you.
