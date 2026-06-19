# Lab 06 — Networking Fundamentals

> **Module format.** Every lab uses the same shape: Objectives, Background, Lab, Verification, Why it matters, Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Inspect interfaces, addresses, and routes with the modern `ip` suite.
- Resolve names with `dig`, `host`, and understand `/etc/resolv.conf`.
- Explain how this VM gets its address via DHCP.
- List listening sockets and the processes behind them with `ss`.
- Capture live traffic with `tcpdump` and scan a host with `nmap`.
- Apply a basic host firewall.
- Triage a "this box can't reach the network" problem methodically, layer by layer.

## Background

A Linux host talks to the network through one or more **interfaces** (e.g. `eth0`/`ens3`), each with an IP **address**, a **route** telling it where to send packets, and a **DNS** configuration telling it how to turn names into addresses. When connectivity breaks, it is almost always one of those four layers — and they have a strict order of dependency: a link with no carrier can't get an address, no address means no route, and no route (or no DNS) means no internet. The whole craft of network triage is checking those layers **in order** instead of guessing.

The old `ifconfig`/`route`/`netstat` tools still exist (`net-tools` is installed) but the modern equivalents are `ip` and `ss` from `iproute2`. Learn the new ones; reach for the old ones only on legacy boxes.

## Lab

### 1. Inspect interfaces and addressing

```bash
ip -brief link             # interfaces and their up/down state, one line each
ip -brief addr             # interfaces and their IPv4/IPv6 addresses
ip addr show               # full detail: MAC, MTU, scope, lifetimes
```

Expected (abridged):

```
lo               UNKNOWN        127.0.0.1/8 ::1/128
ens3             UP             192.168.122.50/24 fe80::5054:ff:fe12:3456/64
```

Note your primary interface name (here `ens3`) and its `/24` address — you'll reuse them. `lo` is the loopback; it is always present.

```bash
ip link show ens3          # link-layer: state UP/DOWN, MTU, MAC address
```

### 2. Inspect routing

```bash
ip route                   # the routing table
```

Expected:

```
default via 192.168.122.1 dev ens3 ...
192.168.122.0/24 dev ens3 proto kernel scope link src 192.168.122.50
```

The `default via` line is the **default gateway** — where any packet not destined for the local subnet is sent. No default route means no internet.

```bash
ip route get 8.8.8.8       # which route/interface would this destination use?
```

### 3. DNS resolution

`/etc/resolv.conf` lists the DNS servers the resolver uses:

```bash
cat /etc/resolv.conf
```

Expected:

```
nameserver 192.168.122.1
search lab.local
```

Resolve a name two ways:

```bash
host debian.org            # short answer
dig debian.org +short      # just the A records
dig debian.org             # full answer with query time and which server answered
dig @1.1.1.1 debian.org +short   # query a specific resolver, bypassing resolv.conf
```

The `dig @server` trick is gold for triage: if the default resolver fails but `@1.1.1.1` works, the problem is your configured DNS, not the network.

### 4. DHCP on this VM (concept)

This VM does **not** have a hardcoded address. At boot it broadcasts a DHCP request; the KVM host's virtual network (libvirt's `default` network, `192.168.122.0/24`) leases it an address, a gateway, and a DNS server — which is exactly the `192.168.122.x` you saw above. Inspect the lease the client recorded:

```bash
ip addr show ens3 | grep -E 'inet .*dynamic'   # 'dynamic' flag => DHCP-assigned
sudo journalctl -u systemd-networkd -b | grep -i -E 'dhcp|lease' | tail
```

Key idea: address, gateway, and DNS all arrive together from DHCP. If DHCP fails, you get a useless `169.254.x.x` link-local address and nothing routes.

### 5. List listening sockets

What is this box accepting connections on?

```bash
sudo ss -tlnp             # TCP, Listening, Numeric ports, Process names
```

Expected (nginx from Lab 05 still running):

```
State   Recv-Q  Send-Q  Local Address:Port   Peer Address:Port  Process
LISTEN  0       511     0.0.0.0:80           0.0.0.0:*          users:(("nginx",pid=...))
LISTEN  0       128     0.0.0.0:22           0.0.0.0:*          users:(("sshd",pid=...))
```

```bash
sudo ss -tulnp           # add -u to include UDP listeners (e.g. DNS, DHCP)
sudo ss -tnp state established   # who is connected right now
```

Flags: `-t` TCP, `-u` UDP, `-l` listening, `-n` numeric (don't resolve names), `-p` show process.

### 6. Capture traffic with tcpdump

> **Run `dig` in a second terminal while this captures**, so there is something to see.

```bash
sudo tcpdump -i any -c 5 -n port 53
```

In another terminal run `dig debian.org`. Back in the capture you'll see the DNS query leave and the response return:

```
14:10:02.111 IP 192.168.122.50.51234 > 192.168.122.1.53: ... A? debian.org.
14:10:02.131 IP 192.168.122.1.53 > 192.168.122.50.51234: ... A 151.101.x.x
```

Flags: `-i any` all interfaces, `-c 5` stop after 5 packets, `-n` don't resolve names (faster, clearer). Try `-c 5 icmp` while running `ping -c 3 192.168.122.1` to watch echo request/reply.

### 7. Scan a host with nmap

```bash
nmap localhost
```

Expected:

```
PORT   STATE SERVICE
22/tcp open  ssh
80/tcp open  http
```

```bash
nmap -p 22,80,443 localhost      # check specific ports
nmap -sV -p 80 localhost         # probe for service/version on port 80
```

`nmap` confirms from the outside what `ss` showed from the inside — useful when a service claims to listen but a firewall is silently blocking it.

### 8. A basic host firewall (nftables)

Debian 12 uses **nftables** natively. Apply a minimal policy that keeps SSH and HTTP reachable and drops everything else inbound.

> **Snapshot first** (from the KVM host): `sudo virsh snapshot-create-as linux-lab pre-lab06 "before firewall"`. A bad rule can lock you out — roll back with `sudo virsh snapshot-revert linux-lab pre-lab06`.

```bash
sudo nft add table inet lab
sudo nft 'add chain inet lab input { type filter hook input priority 0 ; policy drop ; }'
sudo nft add rule inet lab input ct state established,related accept
sudo nft add rule inet lab input iif lo accept
sudo nft add rule inet lab input tcp dport { 22, 80 } accept
sudo nft add rule inet lab input ip protocol icmp accept
```

Inspect and test:

```bash
sudo nft list ruleset            # show the active policy
curl -sI http://localhost | head -1   # still HTTP/1.1 200 OK (port 80 allowed)
nmap -p 22,80,443 localhost      # 443 now shows filtered/closed
```

This ruleset is **not persistent** — it vanishes on reboot, which is exactly what you want while learning. (To persist, you would write it into `/etc/nftables.conf` and enable `nftables.service`.) Tear it down when done in Cleanup.

### 9. Methodical triage: "this host can't reach the internet"

When connectivity breaks, do **not** guess. Walk the layers bottom-up; the first failing layer is your culprit. Each step has the command and what a healthy answer looks like.

```bash
# (1) LINK — is the interface up with a carrier?
ip -brief link show ens3         # state UP  (DOWN => bring it up / check cabling/VM nic)
sudo ip link set ens3 up         # fix if down

# (2) IP — does it have a real address (not 169.254.x.x)?
ip -brief addr show ens3         # expect a 192.168.122.x/24  (169.254 => DHCP failed)
sudo dhclient -v ens3            # request a lease if missing

# (3) GATEWAY — is there a default route, and does the gateway answer?
ip route | grep default          # expect: default via 192.168.122.1
ping -c 2 192.168.122.1          # gateway replies => local network is fine

# (4) DNS — can names resolve? (test routing past the gateway with a raw IP first)
ping -c 2 1.1.1.1                # IP works but names don't => DNS problem
dig debian.org +short            # empty/timeout => check /etc/resolv.conf
dig @1.1.1.1 debian.org +short   # works via 1.1.1.1 => your configured resolver is the issue
cat /etc/resolv.conf             # confirm a valid 'nameserver' line

# (5) END TO END — confirm the fix
ping -c 2 debian.org             # name resolves AND replies => fully back
curl -sI https://debian.org | head -1
```

The discipline is the lesson: **link → IP → gateway → DNS → end-to-end.** If `ping 1.1.1.1` works but `ping debian.org` fails, you have proven it's DNS and can stop checking cables. That single deduction saves hours on a real incident.

## Verification

- `ip -brief addr` shows your primary interface with a `192.168.122.x/24` address, and `ip route` shows a `default via` line.
- `dig debian.org +short` returns one or more IP addresses.
- `sudo ss -tlnp` shows nginx listening on `:80`, and `nmap localhost` reports port 80 open.
- With the firewall applied, `curl -sI http://localhost` still returns `200`, while `nmap` shows 443 filtered.
- You can recite the five triage layers in order and name the command for each.

## Why it matters

Network problems are the single most common ticket in a NOC, and the technician who wins is the one who isolates the layer instead of randomly restarting things. Reading `ip addr`/`ip route`, confirming DNS with `dig @server`, watching packets with `tcpdump`, and proving where the break is with a ping to a raw IP versus a name — these are the exact moves that turn a vague "the internet is down" into a precise, fixable fault. This bottom-up method scales from one VM to a rack of servers.

## Cleanup

```bash
sudo nft delete table inet lab   # remove the firewall ruleset
sudo nft list ruleset            # confirm it's gone (empty or back to defaults)
```

Networking and addressing are unchanged by this lab; nothing else to undo. nginx can keep running for later modules.

Write a short runbook of what you did in this lab — especially the five-layer triage sequence and how you proved which layer was at fault.
