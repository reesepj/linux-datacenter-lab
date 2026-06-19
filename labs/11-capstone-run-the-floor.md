# Lab 11 — Capstone: Run the Floor

> **Module format.** This capstone keeps the course shape — Objectives, Background, then the timed scenario (setup + injects) in place of a single linear Lab, followed by Verification, Why it matters, and Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Run a timed, simulated incident shift that combines storage, services, networking, and disk-space skills from the whole course.
- Detect, diagnose, fix, and **verify** four independent incidents under time pressure.
- Document every action so another technician could follow your work.
- Score yourself against a grading rubric and produce a real incident report.

## Background

You are on shift. During a shift, things break with no warning and no instructions — your job is to notice, triage, fix, and confirm the fix held, while leaving a paper trail. This capstone gives you four **incident injects**. For each one you trigger the fault yourself (acting as "the thing that broke"), then switch hats and resolve it as the on-call technician.

Work in `tmux` so you can keep a notes pane open. Start a timer and write down the clock time when each inject begins and ends — time-to-resolution is part of your grade.

**Snapshot first** — this is the riskiest lab; you will deliberately break storage, services, and networking:

```bash
sudo virsh snapshot-create-as linux-lab pre-capstone "before run-the-floor"
```

Roll back any time with:

```bash
sudo virsh snapshot-revert linux-lab pre-capstone
```

## Setup — build the floor

Prepare a notes file and a tmux session:

```bash
tmux new -s shift
# Ctrl-b " to split; keep one pane for notes:
echo "Shift log $(date '+%F %T')" > ~/shift-notes.md
```

Build the standing infrastructure the injects will attack. **Spare disks only** (`/dev/vdb`, `/dev/vdc`, `/dev/vdd`) — never `/dev/vda`.

```bash
# RAID1 mirror for inject A
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/vdb /dev/vdc
sudo mkfs.xfs -f /dev/md0
sudo mkdir -p /srv/data
sudo mount /dev/md0 /srv/data

# a small filesystem for inject D
sudo mkfs.ext4 -F /dev/vdd
sudo mkdir -p /srv/logs
sudo mount /dev/vdd /srv/logs

# a service for inject B (already present from Lab 09/10)
sudo systemctl enable --now nginx
curl -s -o /dev/null -w '%{http_code}\n' http://localhost   # Expected: 200
```

Note the second network interface name for inject C:

```bash
ip -brief addr     # identify the lab interface, e.g. enp1s0 (NOT your SSH interface)
```

> If you have only one interface and it carries your SSH session, do inject C from the KVM host console, or skip the down-the-interface step and instead break DNS (`/etc/resolv.conf`) — the triage skill is the same.

When the floor is built, **start your clock.**

---

## Incident Injects

For each inject: record the start time, find the problem (don't assume — confirm with tools), fix it, then prove the fix. Log every command's purpose in `~/shift-notes.md`.

### Inject A — Degraded RAID array

**Trigger the fault:**

```bash
sudo mdadm /dev/md0 --fail /dev/vdc --remove /dev/vdc
```

**What you should detect:** the mirror is now running on one disk.

```bash
cat /proc/mdstat                 # shows [U_] — one device missing
sudo mdadm --detail /dev/md0     # State: clean, degraded
```

**Fix:** re-add the spare and let it rebuild.

```bash
sudo mdadm /dev/md0 --add /dev/vdc
watch -n2 cat /proc/mdstat       # watch "recovery" progress to 100%, then Ctrl-c
```

**Success criteria:** `/proc/mdstat` shows `[UU]`, `mdadm --detail /dev/md0` reports `State: clean`, and `/srv/data` is still mounted and readable (`ls /srv/data`). No data loss.

### Inject B — Service down

**Trigger the fault:**

```bash
sudo systemctl stop nginx
```

**What you should detect:** the web service is not answering.

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost   # connection refused / no 200
systemctl is-active nginx                                   # inactive
sudo systemctl status nginx --no-pager                      # read the failure reason
sudo journalctl -u nginx --no-pager -n 20                   # confirm root cause
```

**Fix:** restore the service and confirm it stays up.

```bash
sudo systemctl start nginx
sudo systemctl enable nginx      # ensure it survives reboot
```

**Success criteria:** `systemctl is-active nginx` prints `active` and `curl http://localhost` returns `200`.

### Inject C — Host lost network

**Trigger the fault** (use the lab interface, **not** your SSH interface — substitute the real name from setup):

```bash
sudo ip link set enp1s0 down
```

**What you should detect:** the interface is down and traffic on it fails.

```bash
ip -brief addr                   # interface shows DOWN / no address
ip route                         # missing route via that interface
ping -c2 <gateway-ip>            # fails while the link is down
```

Work the triage ladder: link → address → route → DNS.

**Fix:**

```bash
sudo ip link set enp1s0 up
# if the address/route did not return automatically, renew via the manager:
sudo systemctl restart networking 2>/dev/null || sudo dhclient enp1s0
ip -brief addr                   # interface UP with an address
ping -c2 <gateway-ip>            # Expected: replies
```

**Success criteria:** the interface is `UP` with an IP, the route is present, and `ping` to the gateway succeeds. (If you broke DNS instead, `nslookup debian.org` resolves again.)

### Inject D — Filling disk

**Trigger the fault:**

```bash
sudo fallocate -l 1700M /srv/logs/runaway.bin   # /srv/logs is on the 2G /dev/vdd
df -h /srv/logs                                  # Use% jumps near 100%
```

**What you should detect:** the filesystem is nearly full and you must find the offender.

```bash
df -h                            # spot the full mount
sudo du -xh /srv/logs | sort -rh | head     # largest consumers
sudo ncdu /srv/logs              # interactive: confirm runaway.bin is the culprit
```

**Fix:** remove the runaway file (in real life: rotate/compress/relocate, and confirm nothing still holds the deleted file open with `lsof`).

```bash
sudo rm /srv/logs/runaway.bin
df -h /srv/logs                  # Use% back to normal
sudo lsof +L1 /srv/logs 2>/dev/null   # confirm no deleted-but-open files holding space
```

**Success criteria:** `/srv/logs` usage is back to a healthy level and the service writing there (if any) is happy.

---

## Grading Rubric

Score each inject out of 20 (80 total). Be honest — the rubric is the point.

| Criterion | Points | What earns it |
|---|---|---|
| **Detection** | 4 | You confirmed the fault with tools before acting (didn't guess). |
| **Correct fix** | 6 | The fix addressed the root cause, not a symptom; spare disks only; OS disk untouched. |
| **Verification** | 5 | You proved the fix with a command whose output shows healthy state. |
| **Documentation** | 3 | `~/shift-notes.md` records what you saw, did, and confirmed. |
| **Time** | 2 | Resolved within a reasonable window (target: < 10 min/inject). |

Tally: **70–80** = ready for an on-call rotation. **50–69** = solid, tighten verification/docs. **< 50** = re-run the relevant earlier lab and try the capstone again.

## Final deliverable — write the incident report

Close the shift by writing one report covering all four injects. Use this skeleton in `~/incident-report.md`:

```
# Incident Report — Run the Floor (<date>)

## Summary
One paragraph: what happened across the shift and current status.

## Timeline
Per inject: detected at HH:MM, resolved at HH:MM, time-to-resolution.

## Per-incident detail
For A/B/C/D:
- Symptom (what alerted you / what you observed)
- Root cause
- Actions taken (key commands)
- Verification (the command + output proving it was fixed)

## Follow-ups / prevention
What monitoring, automation (Lab 10), or hardening (Lab 09) would have caught
this sooner or prevented it.
```

## Verification

- All four injects meet their success criteria simultaneously:

```bash
cat /proc/mdstat                                   # [UU], clean
systemctl is-active nginx                          # active
curl -s -o /dev/null -w '%{http_code}\n' http://localhost   # 200
ip -brief addr                                     # lab interface UP with IP
df -h /srv/logs                                    # healthy Use%
```

- `~/shift-notes.md` and `~/incident-report.md` exist and are filled in.

## Why it matters

This *is* the job. A shift on a data center, NOC, or infrastructure team is exactly this loop: notice something is wrong, confirm it with tools, fix the root cause on the right hardware, prove the fix held, and write it up so the next person isn't flying blind. Doing it across storage, services, and networking at once — under a clock, with documentation — is the capstone skill the entire course was building toward.

## Cleanup

Tear down the floor (spare disks only) or simply roll back:

```bash
sudo umount /srv/data /srv/logs
sudo mdadm --stop /dev/md0
sudo mdadm --zero-superblock /dev/vdb /dev/vdc
sudo wipefs -a /dev/vdb /dev/vdc /dev/vdd
sudo rmdir /srv/data /srv/logs
```

```bash
sudo virsh snapshot-revert linux-lab pre-capstone
```

Write a short runbook from this shift: the four incidents, how you detected and fixed each, how you verified, and what you would automate or monitor to prevent a repeat.
