# Lab 07 — Troubleshooting and Break-Fix

> **Module format.** Every lab uses the same shape: Objectives, Background, Lab, Verification, Why it matters, Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Apply a repeatable troubleshooting method instead of guessing.
- Deliberately break a filesystem, an `/etc/fstab` entry, a service, and system load — then recover each.
- Know which tools confirm a fault and which confirm a fix.
- Build the habit of changing one thing at a time and verifying before moving on.

## Background

Under pressure, the temptation is to start changing things. The technicians who get systems back fastest do the opposite: they slow down for thirty seconds and follow a method. The method here is simple and works for almost any incident:

1. **Reproduce / scope** — confirm the symptom and find its blast radius. One host or many? One service or the box?
2. **Isolate** — narrow to a subsystem (disk, network, service, memory, config).
3. **Hypothesize** — form one testable theory of the cause.
4. **Change one thing** — make a single, reversible change.
5. **Verify** — prove the symptom is gone, not just that the command exited 0.
6. **Document** — write down what broke, what you changed, and how you confirmed the fix.

Changing one variable at a time is the whole game. If you change three things and it works, you have learned nothing and cannot trust the result.

Several drills below modify mount config and system state. **Take a snapshot from the KVM host first** so any drill is fully reversible:

```bash
# on the KVM host, not inside the VM:
sudo virsh snapshot-create-as linux-lab pre-lab07 "before break-fix drills"
# to undo everything later:
sudo virsh snapshot-revert linux-lab pre-lab07
```

## Lab

### 1. Prepare a practice mount on a spare disk

All destructive storage work happens on a spare disk, never `/dev/vda`.

```bash
sudo mkfs.ext4 -F /dev/vdb            # format the spare disk
sudo mkdir -p /srv/practice
sudo mount /dev/vdb /srv/practice
df -h /srv/practice
```

Expected:

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/vdb        2.0G   24K  1.9G   1% /srv/practice
```

### 2. Drill A — full filesystem

**Break.** Fill the practice mount with one large file.

```bash
sudo fallocate -l 1.9G /srv/practice/bigfile
```

**Observe.** The "disk full" symptom techs see constantly:

```bash
df -h /srv/practice
sudo touch /srv/practice/another && echo "write ok" || echo "write FAILED"
```

Expected: `Use%` near `100%`, and the write fails with *No space left on device*.

```
/dev/vdb        2.0G  1.9G     0 100% /srv/practice
write FAILED
```

**Find the culprit.** On a real box you will not know what filled it:

```bash
sudo du -ahx /srv/practice | sort -rh | head -n 5
```

**Fix and verify.**

```bash
sudo rm /srv/practice/bigfile
df -h /srv/practice
sudo touch /srv/practice/another && echo "write ok"   # now succeeds
```

### 3. Drill B — broken /etc/fstab

A bad `fstab` line is one of the most common ways to make a box fail to boot. **Confirm your snapshot exists before this drill.**

**Break.** Add a mount entry pointing at a device that does not exist.

```bash
echo '/dev/vdz /mnt/ghost ext4 defaults 0 0' | sudo tee -a /etc/fstab
sudo mkdir -p /mnt/ghost
```

**Observe** the failure mode *without rebooting* — `mount -a` simulates what boot does:

```bash
sudo mount -a; echo "exit code: $?"
```

Expected: a nonzero exit and an error such as *special device /dev/vdz does not exist*. On a real reboot this can drop the host into emergency mode.

**Fix.** Remove the bad line. Edit precisely; do not delete real entries.

```bash
sudo cp /etc/fstab /etc/fstab.bak       # always back up before editing fstab
sudo vim /etc/fstab                      # delete the /dev/vdz line
```

**Verify** the config is sound before you ever trust it at boot:

```bash
sudo mount -a; echo "exit code: $?"      # must be 0
findmnt --verify                          # validates fstab consistency
sudo rmdir /mnt/ghost
```

> Habit: after editing `fstab`, always run `sudo mount -a` and `findmnt --verify`. A clean exit here is what stands between you and a 3 a.m. emergency-mode call.

### 4. Drill C — dead service

**Break.** Stop the web server, simulating a crashed daemon.

```bash
sudo systemctl stop nginx
```

**Observe.** Diagnose like an incident: is it running, is it listening, why did it stop?

```bash
systemctl is-active nginx                 # prints: inactive
sudo ss -ltnp | grep ':80' || echo "nothing listening on 80"
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost/ || echo "connection refused"
sudo systemctl status nginx --no-pager
sudo journalctl -u nginx -n 20 --no-pager
```

Expected: `inactive`, nothing on port 80, and `curl` fails to connect.

**Fix and verify.**

```bash
sudo systemctl start nginx
systemctl is-active nginx                 # prints: active
sudo ss -ltnp | grep ':80'                # nginx now listening
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost/   # prints: 200
```

### 5. Drill D — high load

**Break.** Pin every CPU with busy loops. Note the PIDs so you can kill them.

```bash
nproc                                     # how many CPUs we have
for i in $(seq 1 "$(nproc)"); do yes > /dev/null & done
jobs -p                                   # background PIDs of the yes loops
```

**Observe** the load climb. Open a second pane (`tmux`) or run these directly:

```bash
uptime                                    # 1/5/15-min load averages rising
vmstat 1 3                                # 'r' column (run queue) high, idle near 0
top -b -n1 | head -n 12                   # 'yes' processes at the top by %CPU
```

Expected: load average climbing toward (and past) the CPU count; idle CPU near zero.

**Fix and verify.** Kill the offenders, then confirm load settles.

```bash
kill $(jobs -p)                           # stop the loops we started
# safety net if any escaped the job table:
pkill -x yes
uptime                                    # load average falling
top -b -n1 | head -n 8                    # no 'yes' near the top
```

## Verification

- Drill A: `df -h /srv/practice` shows free space restored and a write succeeds.
- Drill B: `sudo mount -a` exits `0` and `findmnt --verify` reports no errors.
- Drill C: `systemctl is-active nginx` prints `active` and `curl localhost` returns `200`.
- Drill D: `uptime` load averages fall back toward idle and no `yes` processes remain (`pgrep -x yes` returns nothing).

## Why it matters

Incidents in a data center or NOC are rarely exotic — they are full disks, bad config pushed to a mount, a daemon that died, and runaway load. The value you add is not knowing the answer in advance; it is working the problem calmly and reversibly: scope it, isolate it, change one thing, verify, and leave a written trail the next shift can follow. That discipline is exactly what separates a reliable operator from someone who makes outages worse.

## Cleanup

```bash
sudo umount /srv/practice
sudo rmdir /srv/practice
# restore fstab if your backup is cleaner than your edit:
# sudo mv /etc/fstab.bak /etc/fstab
sudo rm -f /etc/fstab.bak
```

Then snapshot a known-good state, or revert to `pre-lab07` if you want a pristine box:

```bash
sudo virsh snapshot-create-as linux-lab post-lab07 "after break-fix drills"
```

> **Write a short runbook** of each drill: what you broke, the exact symptom you saw, the one change that fixed it, and the command that proved the fix. That note is the deliverable, not the reboot.
