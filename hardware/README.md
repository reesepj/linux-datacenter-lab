# Homelab Hardware Guide

You do **not** need a server rack to build real Linux, networking, and data center skills. This lab runs on a single machine you may already own. But once you want to go further — running multiple nodes, practicing real networking, and touching the kind of gear used in production — a small, cheap homelab pays for itself fast.

This guide focuses on **value**: used and refurbished enterprise gear that costs a fraction of new and teaches you the most per dollar. Prices are rough US estimates for the used market and will vary.

## Start here (under ~$200 total)

| Item | Why it matters | Rough used price |
| --- | --- | --- |
| **Refurb mini PC** (Dell OptiPlex Micro, Lenovo ThinkCentre Tiny, HP EliteDesk Mini) | Your lab host. Quiet, low power (~10-15W idle), 6th-9th gen i5 with 16-32GB RAM runs many VMs/containers. The single best homelab buy. | $80-180 |
| **Extra RAM (16-32GB)** | More VMs at once. Often the cheapest upgrade for the biggest gain. | $20-50 |
| **A spare SSD** | Fast VM storage and a target for partitioning/filesystem labs. | $20-40 |
| **USB-to-serial (RJ45 console) cable** | Console into switches/routers — exactly how data center networking gear is configured. | $10-15 |

A single refurb mini PC running KVM/libvirt or Proxmox is enough to host this entire lab plus several more VMs.

## Networking (the network side of data center work)

| Item | Why it matters | Rough used price |
| --- | --- | --- |
| **Managed switch** (used Cisco Catalyst 2960, Aruba, or new TP-Link Omada / MikroTik CRS) | VLANs, trunking, port config, spanning tree — real switching practice. A used 2960 is a classic cheap CCNA/networking lab switch. | $30-120 |
| **MikroTik hAP / hEX (RouterOS)** | Affordable, powerful routing, firewall, VLAN, and VPN practice on production-grade software. | $50-80 |
| **pfSense / OPNsense box** (any 2-NIC mini PC) | Build a real firewall/router: rules, NAT, VLANs, VPN, IDS. | repurpose a mini PC |
| **Cat6 patch cables + a label maker** | Cable management and labeling are real, graded skills in data center work. | $15-30 |

## Going bigger (optional, louder, more power)

| Item | Why it matters | Rough used price |
| --- | --- | --- |
| **Used rack server** (Dell PowerEdge R630/R640, HP ProLiant DL360) | The real thing: hot-swap drive bays, redundant PSUs, **iDRAC/iLO out-of-band management**, and rack rails. Loud and power-hungry; best in a garage/basement. | $150-400 |
| **Used HDDs/SSDs (several)** | Build real RAID and ZFS pools; practice failure and rebuild on actual drives. | $10-30 each |
| **Small network rack or shelf** | Mount switches and a patch panel; practice clean cabling. | $40-120 |
| **Used UPS** (APC Back-UPS / Smart-UPS) | Power protection plus practice with `nut`/power monitoring and graceful shutdown. | $40-100 |
| **Raspberry Pi 4/5** | Cheap always-on node for Pi-hole, DNS, monitoring, or a lightweight cluster member. | $50-80 |

## Buying tips

- **Buy used/refurb.** Off-lease enterprise gear (eBay, r/homelabsales, local recyclers) is built to last and sells for pennies on the dollar.
- **Prioritize RAM, then storage.** Most homelab walls are memory walls.
- **One node is enough to start.** Add a second only when you want clustering, high availability, or live-migration practice.
- **Power and noise are real.** Mini PCs sip power and stay silent; rack servers do not. Match the gear to where it will live.
- **Out-of-band management (iDRAC/iLO/IPMI) is worth seeking out** if you want experience that maps directly to data center operations.

## A sensible starter build

1. One refurb mini PC (16-32GB RAM) running Proxmox or plain KVM/libvirt — hosts this lab and more.
2. One used managed switch + a USB-to-serial cable — real networking practice.
3. A couple of spare drives — RAID/ZFS/LVM practice on physical disks.

Total: roughly **$150-300**, and it covers the large majority of the hands-on skills this course teaches.
