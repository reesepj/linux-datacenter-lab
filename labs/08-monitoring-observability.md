# Lab 08 — Monitoring and Observability

> **Module format.** Every lab uses the same shape: Objectives, Background, Lab, Verification, Why it matters, Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Inspect CPU, memory, I/O, and disk with the standard tools (`top`, `htop`, `vmstat`, `iostat`, `free`, `df`, `du`, `ncdu`).
- Collect and read historical metrics with `sysstat`/`sar`.
- Read system logs from `/var/log` and `journalctl`.
- Write a small health-check script that reports disk usage, load, failed services, and listening ports.
- Speak the basic vocabulary of metrics, observability, and capacity.

## Background

You cannot fix what you cannot see. Monitoring answers two questions: *is it healthy right now?* and *is it trending toward trouble?* The first is a spot check; the second needs history.

A few terms used across operations, vendor-neutral:

- **Metric** — a number sampled over time (CPU %, load average, disk used %, packets/sec).
- **Utilization vs saturation** — utilization is how busy a resource is; saturation is how much work is queued waiting for it (e.g. the `r` run-queue column in `vmstat`). Saturation usually hurts before utilization hits 100%.
- **Observability** — the ability to ask new questions of a running system from its outputs (metrics, logs, traces) without shipping new code.
- **Baseline** — what "normal" looks like. You can only spot an anomaly if you know the baseline.
- **Capacity** — headroom before a resource runs out. Operations work is largely watching trends and acting before the headroom is gone.

This module is read-only inspection plus one small script — no destructive steps. No snapshot required, but feel free to take one out of habit.

## Lab

### 1. CPU and run queue

```bash
uptime                       # load averages: 1, 5, 15 minutes
vmstat 1 3                   # r=run queue, us/sy=cpu%, wa=io wait, id=idle
mpstat 1 3                   # per-CPU breakdown (from sysstat)
```

Expected: on an idle box, load near `0.0`, `vmstat` `id` near `100`, `wa` near `0`.

### 2. Interactive process views

```bash
top -b -n1 | head -n 12      # batch snapshot: top processes by CPU
htop                         # interactive; F6 sorts, F9 kills, q quits
```

In `top`, the header summarizes load, tasks, CPU%, and memory. `htop` shows the same with color bars and per-core meters — press `q` to exit.

### 3. Memory

```bash
free -h                      # total/used/free/available memory and swap
vmstat -s | head -n 12       # detailed memory + paging counters
```

Read `available`, not `free` — Linux uses spare RAM for cache and reclaims it on demand, so low "free" is normal and healthy.

### 4. Disk capacity and I/O

```bash
df -h                        # capacity per filesystem (watch Use%)
df -i                        # inodes — a disk can be "full" on inodes alone
iostat -xz 1 3               # per-device I/O; %util and await show pressure
lsblk                        # device tree
```

Expected: `iostat` `%util` near `0` when idle; a busy disk approaches `100%` with rising `await` (ms per I/O).

### 5. What is using the space

```bash
sudo du -shx /var/* 2>/dev/null | sort -rh | head -n 10    # biggest dirs under /var
sudo ncdu /var                                              # interactive size browser; q to quit
```

`ncdu` is the fastest way to answer "what filled the disk?" — navigate with arrows, quit with `q`.

### 6. Historical metrics with sar

`sysstat` collects metrics on a schedule so you can look backward, not just at this instant.

```bash
sudo systemctl enable --now sysstat        # start the collector
sar -u 1 3                                  # CPU utilization, live
sar -r 1 3                                  # memory utilization, live
sar -d 1 3                                  # disk activity, live
# after data has accumulated, read today's history:
sar -u | tail -n 10                         # CPU over the day
```

Expected: tabular samples with timestamps. Historical reports populate as the collector runs (typically every 10 minutes).

### 7. Reading logs

```bash
sudo journalctl -p err -b --no-pager | tail -n 20   # errors this boot
sudo journalctl -u nginx -n 20 --no-pager           # one service's logs
sudo journalctl -f                                   # follow live; Ctrl-C to stop
sudo tail -n 20 /var/log/syslog                      # classic text log
ls -lh /var/log                                      # what logs exist and their sizes
```

`-p err` filters by priority; `-b` limits to the current boot; `-u` scopes to a unit. These three flags cover most log triage.

### 8. Write a health-check script

A one-shot health check is something every operator ends up writing. Create it:

```bash
mkdir -p ~/bin
vim ~/bin/healthcheck.sh
```

Paste the following:

```bash
#!/usr/bin/env bash
# healthcheck.sh - quick system health snapshot
set -uo pipefail

DISK_WARN=85   # percent

echo "=== Health check: $(hostname) at $(date '+%F %T') ==="

echo
echo "## Load average"
uptime | sed 's/.*load average/load average/'

echo
echo "## Disk usage (warn >= ${DISK_WARN}%)"
df -hP | awk -v w="$DISK_WARN" 'NR==1 {print; next}
  $1 ~ /^\/dev\// {
    use = $5; gsub(/%/, "", use)
    flag = (use+0 >= w) ? "  <-- WARN" : ""
    printf "%s%s\n", $0, flag
  }'

echo
echo "## Failed systemd units"
failed=$(systemctl --failed --no-legend --plain | awk '{print $1}')
if [ -z "$failed" ]; then
  echo "none"
else
  echo "$failed"
fi

echo
echo "## Listening ports (TCP)"
ss -ltnH | awk '{print $4}' | sort -u

echo
echo "=== end ==="
```

Make it executable and run it:

```bash
chmod +x ~/bin/healthcheck.sh
~/bin/healthcheck.sh
```

Expected output (abridged):

```
=== Health check: linux-lab at 2026-06-19 14:02:11 ===

## Load average
load average: 0.00, 0.01, 0.00

## Disk usage (warn >= 85%)
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1        39G  3.2G   34G   9% /

## Failed systemd units
none

## Listening ports (TCP)
0.0.0.0:22
0.0.0.0:80

=== end ===
```

### 9. Exercise the warning path (optional, on a spare disk)

Confirm the disk warning actually fires, using a spare disk only:

```bash
sudo mkfs.ext4 -F /dev/vdb
sudo mkdir -p /srv/mon && sudo mount /dev/vdb /srv/mon
sudo fallocate -l 1.9G /srv/mon/fill
~/bin/healthcheck.sh | grep -A4 'Disk usage'   # /srv/mon line shows <-- WARN
sudo rm /srv/mon/fill && sudo umount /srv/mon && sudo rmdir /srv/mon
```

## Verification

- `vmstat`, `free -h`, `df -h`, and `iostat` all produce sane readings for an idle box.
- `sar -u 1 3` prints timestamped CPU samples (sysstat is collecting).
- `journalctl -p err -b` runs and `ls -lh /var/log` lists logs.
- `~/bin/healthcheck.sh` runs cleanly and prints load, disk usage, failed units, and listening ports; the optional drill makes a filesystem show `<-- WARN`.

## Why it matters

On an operations floor you are paid to notice trouble before users do. That means knowing the spot-check tools cold, having historical metrics (`sar`) to spot trends, reading logs to confirm a cause, and packaging your knowledge into a script anyone on the team can run. A simple, correct health check that flags a filling disk or a failed service is worth more at 3 a.m. than any dashboard you have to think about.

## Cleanup

```bash
rm -f ~/bin/healthcheck.sh        # keep it if you want; it is genuinely useful
# sysstat can stay enabled — historical metrics are a good habit:
# sudo systemctl disable --now sysstat   # only if you want it off
```

> **Write a short runbook**: note which command answers which question (full disk -> `ncdu`/`du`, slow box -> `vmstat`/`iostat`, dead service -> `journalctl -u`), and keep a copy of your health-check script where the next shift can find it.
