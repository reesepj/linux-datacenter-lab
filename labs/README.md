# The Course

Twelve modules that take you from a fresh Linux box to running a simulated operations floor. Work them in order; each builds on the last.

Every module follows the same shape:

1. **Objectives** — what you will be able to do.
2. **Background** — the concepts, briefly.
3. **Lab** — numbered, hands-on steps.
4. **Verification** — how to confirm it worked.
5. **Why it matters** — how this shows up in data center and ops roles.
6. **Cleanup** — reset for the next module.

## Modules

- [00 — Getting Started](00-getting-started.md)
- [01 — Linux Fundamentals](01-linux-fundamentals.md)
- [02 — Storage: Disks, Partitions, Filesystems](02-storage-filesystems.md)
- [03 — RAID with mdadm](03-raid-mdadm.md)
- [04 — LVM](04-lvm.md)
- [05 — systemd and Services](05-systemd-services.md)
- [06 — Networking Fundamentals](06-networking-fundamentals.md)
- [07 — Troubleshooting and Break-Fix](07-troubleshooting-break-fix.md)
- [08 — Monitoring and Observability](08-monitoring-observability.md)
- [09 — Security Basics](09-security-basics.md)
- [10 — Automation and Scripting](10-automation-scripting.md)
- [11 — Capstone: Run the Floor](11-capstone-run-the-floor.md)

## How to get the most from it

- **Type the commands.** Reading is not reps.
- **Write a runbook for every lab.** A short note of what you did, what broke, and how you fixed it. This habit is exactly what operations teams value, and it is what you will reference under pressure.
- **Break things on purpose.** Snapshot, sabotage, then recover. The recovery is the skill.
- **Practice on the spare disks only** (`/dev/vdb`, `/dev/vdc`, `/dev/vdd`). Never the OS disk (`/dev/vda`).
