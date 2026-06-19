# Linux Data Center Lab

A hands-on, self-hosted lab and course for building real **Linux, networking, and data center operations** skills — the practical foundation behind data center technician, NOC, systems administration, and infrastructure roles.

Spin up a disposable Debian virtual machine with spare disks and a full operations toolset, then work through a structured course: storage and RAID, LVM, systemd and services, networking, troubleshooting, monitoring, security, and automation, finishing with a capstone incident-response shift.

Everything runs on free, open-source tooling (KVM/libvirt) and on hardware you may already own. It is designed so you can **break things safely and rebuild them**, which is how operations skills actually stick.

## Why this exists

Data center and infrastructure work is hands-on. Reading about RAID rebuilds, failed services, or a host that cannot reach the network does not build the reflexes that the job (and the interview) demands. This lab gives you a safe, reproducible place to get those reps and to document them like a professional.

## What you get

- **A reproducible lab VM** (Debian, via KVM/libvirt) with three blank spare disks for storage labs and a full ops toolset preinstalled.
- **A structured course** in [`labs/`](labs/) — twelve modules from Linux fundamentals to a capstone incident shift.
- **A homelab hardware guide** in [`hardware/`](hardware/README.md) — cheap, useful gear for building out a real home lab.
- **Provisioning scripts** in [`provisioning/`](provisioning/) so the whole environment is one command to build and one command to connect.

## Quick start

On a Linux host with virtualization support (Intel VT-x / AMD-V):

```bash
# 1. Install the KVM stack (Debian/Ubuntu)
sudo apt update && sudo apt install -y \
  qemu-kvm libvirt-daemon-system libvirt-clients virtinst libguestfs-tools

# 2. Build the lab VM (Debian + spare disks + ops toolset)
./provisioning/build-lab-vm.sh

# 3. Connect to it
./provisioning/lab-connect.sh

# 4. Start the course
#    open labs/00-getting-started.md and work forward
```

Default login inside the VM is user `labuser` / password `changeme` with passwordless sudo. Change it on first login (`passwd`).

## Course outline

| # | Module | Skills |
| --- | --- | --- |
| 00 | [Getting Started](labs/00-getting-started.md) | Environment, conventions, safety, snapshots |
| 01 | Linux Fundamentals | Filesystem, users, permissions, processes, packages |
| 02 | Storage: Disks, Partitions, Filesystems | parted, gdisk, mkfs, mount, fstab |
| 03 | RAID with mdadm | Build, degrade, rebuild, monitor arrays |
| 04 | LVM | PV/VG/LV, resize, snapshots |
| 05 | systemd and Services | Units, journald, service troubleshooting |
| 06 | Networking Fundamentals | IP, routing, DNS, DHCP, firewall, ss, tcpdump |
| 07 | Troubleshooting and Break-Fix | A repeatable methodology and drills |
| 08 | Monitoring and Observability | Resource analysis, logs, health checks |
| 09 | Security Basics | SSH hardening, users, sudo, updates |
| 10 | Automation and Scripting | Bash, cron, idempotent provisioning |
| 11 | Capstone: Run the Floor | A timed, multi-system incident shift |

## The lab environment

- **OS:** Debian 12 (a clean, widely deployed server distribution; the same family used as the base of many production Linux fleets).
- **Disks:** a 40 GB OS disk (`/dev/vda`) plus three blank spare disks (`/dev/vdb`, `/dev/vdc`, `/dev/vdd`) for storage, RAID, and LVM labs.
- **Toolset:** mdadm, lvm2, parted, gdisk, smartmontools, xfsprogs, net-tools, iproute2, dnsutils, tcpdump, nmap, sysstat, ncdu, nginx, rsync, jq, vim, tmux, htop, git, and more.
- **Access:** SSH and serial console.
- **Reset anytime:** snapshot before a risky lab and roll back instantly (see Lab 00).

## Repository layout

```
linux-datacenter-lab/
├── README.md
├── LICENSE
├── labs/             # the course, one module per file
├── provisioning/     # build + connect scripts
└── hardware/         # homelab hardware guide
```

## Who this is for

Anyone preparing for data center technician, NOC, junior sysadmin, or infrastructure roles — or any engineer who wants Linux and networking skills that hold up under real conditions. No prior homelab required; a single Linux host is enough to start.

## Contributing

Issues and pull requests are welcome: new labs, fixes, clearer explanations, and additional hardware notes.

## License

[MIT](LICENSE) — use it, fork it, teach with it.
