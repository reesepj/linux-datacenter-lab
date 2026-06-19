# Home Lab Hardware Guide

A practical, detailed guide to the hardware behind this lab: what it runs on, the real minimum to replicate it, specific parts with rough prices, and how to grow a home lab for Linux, networking, and data center operations practice. Prices are rough US used-market estimates and will vary.

## 1. What you are replicating

This entire lab is just **one Linux machine running a hypervisor** (KVM/libvirt). That host creates disposable virtual machines — like the course's lab VM — each with virtual CPUs, RAM, disks, and a virtual network. Nothing exotic is required.

The reference host this was built on:

- **CPU:** Intel Core i5-9400F (6 cores)
- **RAM:** 64 GB
- **Storage:** SSD/NVMe with ~500 GB free
- **GPU:** a discrete card used for unrelated work (the lab does **not** need a GPU)
- **OS:** Ubuntu Linux

The key point: the **lab VM itself is tiny** — about 2 virtual CPUs, 4 GB RAM, and ~45 GB of disk. The reference host is overkill for the course alone. Almost any modern 64-bit PC with virtualization support can run this.

## 2. The only hard requirements

To run this lab you need:

- A 64-bit CPU with hardware virtualization: **Intel VT-x** or **AMD-V** (nearly every CPU from the last decade). Verify on a Linux host with:
  ```bash
  egrep -c '(vmx|svm)' /proc/cpuinfo     # nonzero = supported
  ```
- **~8 GB RAM** free (4 GB for the lab VM plus headroom); 16 GB+ is comfortable.
- **~60 GB free disk** (the VM is 40 GB; leave room for snapshots).
- A **Linux host** (Debian or Ubuntu recommended) with the KVM stack installed.

If you have a spare laptop or desktop from roughly the last eight years, you can likely start today for $0.

## 3. The core build: your home lab host

The single best buy is a **refurbished business mini PC**. Quiet, low power (~10-15 W idle), tiny, and cheap used. One can host this lab plus several more VMs and containers.

| Model family | Look for | Notes |
| --- | --- | --- |
| Dell OptiPlex Micro (7050/7060/7070/7080) | i5-8500T/9500T, 16-32 GB | Excellent value, very common used |
| Lenovo ThinkCentre Tiny (M720q/M920q/M70q) | i5-8400T/9400T or newer | Great build, easy RAM/NVMe upgrades |
| HP EliteDesk/ProDesk Mini (800 G4/G5) | i5-8500/9500 | Solid and widely available |

Target spec to replicate comfortably:

- **CPU:** quad-core or better Intel i5 (8th gen+) or a Ryzen equivalent. More cores means more concurrent VMs.
- **RAM:** 32 GB (16 GB minimum). RAM is the number one homelab limiter; max it out — it is the cheapest big win.
- **Storage:** a 500 GB-1 TB NVMe SSD for VM storage. Fast disk equals responsive VMs.

**Rough cost:** $80-180 for the mini PC, plus $20-50 RAM, plus $30-60 SSD. A capable host for well under $250.

## 4. Storage (and storage-lab practice)

- **Boot/VM drive:** NVMe or SATA SSD, 500 GB-1 TB. Speed matters more than size for VMs.
- **Extra drives for real RAID/ZFS practice:** the course does RAID and LVM on *virtual* spare disks, but practicing on *physical* disks is the natural next step. A few used SATA SSDs or HDDs ($10-30 each) let you build real arrays, physically pull a drive, and rebuild.
- **Optional NAS:** a 2-bay Synology/QNAP, or a DIY box running TrueNAS, for shared storage, backups, and NFS/iSCSI practice. Storage networking is a real data center skill.

## 5. Networking gear (the networking half)

The course teaches networking inside one VM; real switches and routers take it much further.

| Gear | Why it matters | Rough used price |
| --- | --- | --- |
| **Managed switch** (Cisco Catalyst 2960, Aruba 2530; or new MikroTik CRS / TP-Link Omada) | VLANs, trunking, port config, spanning tree | $30-120 |
| **Router/firewall** (MikroTik hEX/hAP, or a 2-NIC mini PC running pfSense/OPNsense) | Routing, NAT, firewall rules, VPN, VLANs | $50-90 or repurpose |
| **USB-to-serial console cable** (Cisco rollover / RJ45) | Console into switches and routers — exactly how data center gear is configured | $10-15 |
| **Cat6 patch cables + a label maker** | Clean cabling and labeling are graded data center skills | $15-30 |

A used Cisco 2960 plus a console cable is the classic, cheap networking-practice combo.

## 6. Going bigger (optional: louder, more power)

When you want production-style experience:

| Gear | Why it matters | Rough used price |
| --- | --- | --- |
| **Used rack server** (Dell PowerEdge R630/R640, HP ProLiant DL360 Gen9/10) | Hot-swap drive bays, redundant PSUs, and **iDRAC/iLO out-of-band management** — the real data center experience | $150-400 |
| **UPS** (APC Back-UPS / Smart-UPS) | Power protection plus practice with graceful shutdown and `nut` monitoring | $40-100 |
| **Small rack or shelf + PDU** | Mount a switch, patch panel, and server; practice clean cabling | $40-150 |
| **Second mini PC / node** | Clustering, Proxmox high availability, live-migration practice | $80-180 |
| **Raspberry Pi 4/5** | Cheap always-on node for Pi-hole, DNS, or monitoring | $50-80 |

Out-of-band management (iDRAC/iLO/IPMI) is the single feature most worth seeking out — it is how data center techs manage servers that are otherwise "down."

## 7. The software stack (all free)

- **Host OS:** Debian or Ubuntu Server (what this lab assumes), or **Proxmox VE** — a polished web UI over KVM that is excellent for homelabs once you have a dedicated host.
- **Virtualization:** `qemu-kvm`, `libvirt`, `virtinst`, `libguestfs-tools` (exactly what `provisioning/build-lab-vm.sh` uses).
- **Management:** `virsh` and `virt-manager` for libvirt, or the Proxmox web UI.
- **Containers (later):** Docker or LXC for lighter services alongside full VMs.

## 8. Three concrete builds

**A. "Just the lab" — $0-150**
Use a PC or laptop you already own (8 GB+ RAM, VT-x/AMD-V), or grab one refurb mini PC. Install the KVM stack, run `build-lab-vm.sh`, and you are done.

**B. "Solid home lab" — about $250-450**
- Refurb mini PC: i5, **32 GB RAM**, 1 TB NVMe ($150-220)
- Used managed switch (Cisco 2960 or MikroTik CRS) ($40-90)
- USB-to-serial console cable ($12)
- 2-3 used SATA SSDs for physical RAID practice ($45)

Covers the large majority of hands-on Linux, networking, and storage skills.

**C. "Going pro" — about $600-1200**
- Used rack server with iDRAC/iLO, dual Xeon, 64-128 GB RAM, hot-swap bays ($250-450)
- Managed switch + small rack + PDU ($150-250)
- Used UPS ($60-100)
- NAS or DIY TrueNAS box ($150-300)

Real rack, real out-of-band management, real redundancy — the closest you get to a production environment at home.

## 9. Buying tips

- **Buy used/refurb.** Off-lease enterprise gear (eBay, r/homelabsales, local IT recyclers) is built to last and sells for a fraction of new.
- **Prioritize RAM, then fast storage.** Most homelab walls are memory walls.
- **One node is enough to start.** Add a second only when you want clustering or high-availability practice.
- **Mind power and noise.** Mini PCs are silent and sip power; rack servers are loud and hot — keep them in a garage or basement.
- **Seek out IPMI/iDRAC/iLO** for experience that maps directly to data center operations.

## 10. Replicating this exact lab

On any Debian/Ubuntu host that meets Section 2:

```bash
sudo apt update && sudo apt install -y \
  qemu-kvm libvirt-daemon-system libvirt-clients virtinst libguestfs-tools

git clone https://github.com/reesepj/linux-datacenter-lab.git
cd linux-datacenter-lab
./provisioning/build-lab-vm.sh      # builds the VM + spare disks + toolset
./provisioning/lab-connect.sh       # connect and start the course
```

That is the whole setup. Everything else in this guide is about growing from "one VM on one box" toward a richer, more production-like environment as your skills and curiosity expand.
