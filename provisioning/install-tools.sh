#!/usr/bin/env bash
set -euo pipefail
#
# install-tools.sh — install the lab toolset into a running lab VM over SSH.
# Run automatically by build-lab-vm.sh, or on its own to (re)install tools.
#
VM="${VM:-linux-lab}"
USER_PASS="${USER_PASS:-changeme}"
PKGS="sudo vim tmux htop git curl wget less lsof strace mdadm lvm2 parted gdisk smartmontools xfsprogs net-tools iproute2 dnsutils tcpdump nmap sysstat tree ncdu rsync jq nginx bash-completion man-db"

echo ">> Waiting for VM IP..."
IP=""
for i in $(seq 1 45); do
  IP=$(sudo virsh domifaddr "$VM" --source lease 2>/dev/null | awk '/ipv4/{print $4}' | cut -d/ -f1 | head -1)
  [ -n "$IP" ] && break
  sleep 3
done
[ -z "$IP" ] && { echo "!! No IP yet. Wait a moment and re-run."; exit 1; }

echo ">> VM IP: $IP — waiting for SSH..."
for i in $(seq 1 40); do timeout 2 bash -c "echo > /dev/tcp/$IP/22" 2>/dev/null && break; sleep 3; done

SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
if command -v sshpass >/dev/null; then
  sshpass -p "$USER_PASS" ssh $SSHOPTS "root@$IP" \
    "export DEBIAN_FRONTEND=noninteractive; apt-get update -y && apt-get install -y $PKGS"
  echo ">> Toolset installed."
else
  echo "!! 'sshpass' not installed, cannot automate. Run this yourself:"
  echo "     ssh root@$IP      # password: $USER_PASS"
  echo "     sudo apt-get update && sudo apt-get install -y $PKGS"
fi
