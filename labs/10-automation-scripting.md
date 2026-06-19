# Lab 10 — Automation and Scripting

> **Module format.** Every lab uses the same shape: Objectives, Background, Lab, Verification, Why it matters, Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Write safe bash scripts using variables, conditionals, loops, functions, and exit codes.
- Understand why `set -euo pipefail` belongs at the top of every serious script.
- Build a real maintenance script: apply updates, check disk space, check a service, and log the result.
- Schedule that script two ways — with `cron` and with a `systemd` timer.
- Explain idempotence and why automation must be safe to re-run.
- Apply a simple fan-out pattern to check many services or hosts in a loop.

## Background

Operations work that you do twice should be a script; work you do on a schedule should be automated. The skill is not clever bash — it is *safe* bash: scripts that fail loudly, log what they did, and are safe to run again. A maintenance job that silently half-fails is worse than no job at all.

Two scheduling systems matter on Linux. `cron` is the classic line-per-job scheduler. `systemd` timers are the modern equivalent — they integrate with the journal, support dependencies, and survive missed runs (`Persistent=true`). Knowing both is expected.

**Snapshot first** (from the KVM host) so a runaway script costs nothing:

```bash
sudo virsh snapshot-create-as linux-lab pre-lab10 "before automation lab"
```

## Lab

### 1. Bash essentials in one script

Create a scratch file and make it executable:

```bash
mkdir -p ~/bin
vim ~/bin/essentials.sh
chmod +x ~/bin/essentials.sh
```

```bash
#!/usr/bin/env bash
set -euo pipefail        # exit on error, undefined var, or failed pipe

# variables
name="floor"
threshold=80

# function with a return (exit) code
disk_ok() {
    local pct
    pct=$(df --output=pcent / | tail -1 | tr -dc '0-9')
    [ "$pct" -lt "$threshold" ]   # last command's status is the function's status
}

# conditional using the function's exit code
if disk_ok; then
    echo "root disk under ${threshold}% — ok"
else
    echo "root disk at or above ${threshold}% — investigate" >&2
    exit 1
fi

# loop
for svc in ssh cron nginx; do
    echo "checking ${svc} on the ${name}..."
done
```

Run it and inspect the exit code:

```bash
~/bin/essentials.sh
echo "exit code: $?"     # Expected: 0 when disk is healthy
```

`set -euo pipefail` is the difference between a script that stops at the first problem and one that blindly continues with bad data. `-e` exits on any error, `-u` treats unset variables as errors, `pipefail` makes a pipeline fail if *any* stage fails.

### 2. Write a real maintenance script

```bash
vim ~/bin/maint.sh
chmod +x ~/bin/maint.sh
```

```bash
#!/usr/bin/env bash
set -euo pipefail

LOG=/var/log/maint.log
DISK_THRESHOLD=85
SERVICE=nginx

log() { echo "$(date '+%F %T') $*" | sudo tee -a "$LOG" >/dev/null; }

log "=== maintenance run start ==="

# 1) apply security/package updates
log "updating package lists"
sudo apt-get update -qq
log "applying upgrades"
sudo apt-get -y upgrade >/dev/null

# 2) disk check
used=$(df --output=pcent / | tail -1 | tr -dc '0-9')
if [ "$used" -ge "$DISK_THRESHOLD" ]; then
    log "WARNING: root disk at ${used}% (threshold ${DISK_THRESHOLD}%)"
else
    log "disk ok: root at ${used}%"
fi

# 3) service check, restart once if down
if systemctl is-active --quiet "$SERVICE"; then
    log "service ${SERVICE}: active"
else
    log "service ${SERVICE}: DOWN — attempting restart"
    sudo systemctl restart "$SERVICE" || log "ERROR: ${SERVICE} failed to restart"
fi

log "=== maintenance run done ==="
```

Run it and read the log:

```bash
~/bin/maint.sh
sudo tail -n 20 /var/log/maint.log
# Expected: timestamped lines for update, disk ok, service active, run done
```

### 3. Schedule it with cron

Edit the current user's crontab:

```bash
crontab -e
```

Add a line to run it every day at 03:30 and capture output:

```
30 3 * * * /home/labuser/bin/maint.sh >> /var/log/maint-cron.log 2>&1
```

List and confirm:

```bash
crontab -l        # Expected: shows the 30 3 * * * line
```

### 4. Schedule it with a systemd timer

Create the service unit (what to run):

```bash
sudo vim /etc/systemd/system/maint.service
```

```
[Unit]
Description=Daily maintenance job

[Service]
Type=oneshot
ExecStart=/home/labuser/bin/maint.sh
```

Create the timer unit (when to run it):

```bash
sudo vim /etc/systemd/system/maint.timer
```

```
[Unit]
Description=Run maintenance daily

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and inspect:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now maint.timer
systemctl list-timers maint.timer --no-pager
# Expected: shows NEXT run time and the maint.timer/maint.service pair
```

Trigger the service manually once to prove the unit works:

```bash
sudo systemctl start maint.service
journalctl -u maint.service --no-pager -n 20
```

### 5. Idempotence

A script is **idempotent** if running it twice has the same effect as running it once. `maint.sh` qualifies: re-running it just appends another log entry and reconverges the system (updates already applied, service already up). Contrast that with an unsafe pattern:

```bash
# NOT idempotent — grows the file every run:
echo "127.0.0.1 cache" >> /etc/hosts

# idempotent — only adds the line if it is missing:
grep -qxF "127.0.0.1 cache" /etc/hosts || echo "127.0.0.1 cache" | sudo tee -a /etc/hosts
```

Scheduled automation must be idempotent, because timers and cron *will* re-run it.

### 6. Fan-out: check many services in a loop

Real fleets have many services (and many hosts). The same loop pattern scales:

```bash
vim ~/bin/check-services.sh
chmod +x ~/bin/check-services.sh
```

```bash
#!/usr/bin/env bash
set -euo pipefail

services=(ssh cron nginx fail2ban)
failed=0

for svc in "${services[@]}"; do
    if systemctl is-active --quiet "$svc"; then
        printf '%-12s OK\n' "$svc"
    else
        printf '%-12s DOWN\n' "$svc"
        failed=$((failed + 1))
    fi
done

echo "summary: ${failed} service(s) down"
exit "$failed"     # non-zero exit when anything is down — usable by a monitor
```

Run it:

```bash
~/bin/check-services.sh
echo "exit: $?"
# Expected: a column of OK/DOWN lines and an exit code equal to the down count
```

The same shape fans out across hosts using SSH (key auth from Lab 09):

```bash
for host in lab-a lab-b lab-c; do
    echo "== ${host} =="
    ssh "$host" 'uptime; df -h / | tail -1'
done
```

## Verification

- `~/bin/maint.sh` runs cleanly and appends timestamped lines to `/var/log/maint.log`.
- `crontab -l` shows the scheduled job.
- `systemctl list-timers maint.timer` shows a NEXT run time.
- `journalctl -u maint.service` shows output from a manual run.
- `~/bin/check-services.sh` prints per-service status and exits with the count of down services.
- Re-running `maint.sh` does not corrupt or duplicate state (idempotent).

## Why it matters

Automation is the multiplier that lets a small team run a large floor. Writing scripts that fail loudly, log their actions, and are safe to re-run — and scheduling them with both cron and systemd timers — is core day-to-day work for sysadmin, NOC, and infrastructure roles. The idempotence and fan-out patterns here are exactly how routine fleet maintenance gets done at scale.

## Cleanup

Disable the schedules and remove the practice files (or roll back to the snapshot):

```bash
crontab -e         # delete the maint.sh line, save
sudo systemctl disable --now maint.timer
sudo rm -f /etc/systemd/system/maint.service /etc/systemd/system/maint.timer
sudo systemctl daemon-reload
rm -f ~/bin/essentials.sh ~/bin/maint.sh ~/bin/check-services.sh
sudo rm -f /var/log/maint.log /var/log/maint-cron.log
```

```bash
sudo virsh snapshot-revert linux-lab pre-lab10
```

Write a short runbook: what your maintenance script does, how you scheduled it both ways, and how you would verify it actually ran.
