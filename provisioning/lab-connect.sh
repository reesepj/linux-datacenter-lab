#!/usr/bin/env bash
set -euo pipefail
#
# lab-connect.sh — start (if needed) and SSH into the lab VM.
# Override the VM name or user via env:  VM=linux-lab USER_NAME=labuser ./lab-connect.sh
#
VM="${VM:-linux-lab}"
USER_NAME="${USER_NAME:-labuser}"

sudo virsh start "$VM" 2>/dev/null || true

echo ">> Locating $VM ..."
IP=""
for i in $(seq 1 30); do
  IP=$(sudo virsh domifaddr "$VM" --source lease 2>/dev/null | awk '/ipv4/{print $4}' | cut -d/ -f1 | head -1)
  [ -n "$IP" ] && break
  sleep 2
done

if [ -z "$IP" ]; then
  echo "!! No IP found. Use the serial console instead:"
  echo "     sudo virsh console $VM    (exit with Ctrl+])"
  exit 1
fi

echo ">> Connecting to ${USER_NAME}@${IP} ..."
exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${USER_NAME}@${IP}"
