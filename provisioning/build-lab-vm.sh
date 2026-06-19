#!/usr/bin/env bash
set -euo pipefail
#
# build-lab-vm.sh — build a disposable Debian lab VM (KVM/libvirt) with three
# spare disks and the ops toolset, for the Linux Data Center Lab course.
#
# Requirements (Debian/Ubuntu host):
#   sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst libguestfs-tools
#
# Configurable via env vars (defaults shown):
#   VM=linux-lab RAM_MB=4096 VCPUS=2 DISK_GB=40 SPARE_GB=2
#   USER_NAME=labuser USER_PASS=changeme IMGDIR=/var/lib/libvirt/images
#
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM="${VM:-linux-lab}"
RAM_MB="${RAM_MB:-4096}"
VCPUS="${VCPUS:-2}"
DISK_GB="${DISK_GB:-40}"
SPARE_GB="${SPARE_GB:-2}"
IMGDIR="${IMGDIR:-/var/lib/libvirt/images}"
USER_NAME="${USER_NAME:-labuser}"
USER_PASS="${USER_PASS:-changeme}"
DISK="$IMGDIR/$VM.qcow2"

for c in virsh virt-install virt-builder qemu-img; do
  command -v "$c" >/dev/null || { echo "Missing '$c'. Install: qemu-kvm libvirt-daemon-system virtinst libguestfs-tools"; exit 1; }
done

if sudo virsh dominfo "$VM" >/dev/null 2>&1; then
  echo ">> Removing existing VM '$VM'..."
  sudo virsh destroy "$VM" 2>/dev/null || true
  sudo virsh undefine "$VM" --remove-all-storage 2>/dev/null || true
fi
sudo rm -f "$IMGDIR/$VM"*.qcow2 2>/dev/null || true

echo ">> Building base image (Debian 12) with virt-builder..."
sudo virt-builder debian-12 \
  --format qcow2 --size "${DISK_GB}G" --output "$DISK" \
  --hostname "$VM" \
  --root-password "password:${USER_PASS}" \
  --run-command "install -d -m0755 /etc/sudoers.d" \
  --run-command "useradd -m -s /bin/bash ${USER_NAME}; echo '${USER_NAME}:${USER_PASS}' | chpasswd; usermod -aG sudo ${USER_NAME}; printf '${USER_NAME} ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-${USER_NAME}; chmod 440 /etc/sudoers.d/90-${USER_NAME}" \
  --run-command "ssh-keygen -A" \
  --run-command "systemctl enable ssh serial-getty@ttyS0.service systemd-networkd.service" \
  --run-command "mkdir -p /etc/systemd/network && printf '[Match]\nName=en* eth*\n\n[Network]\nDHCP=yes\n' > /etc/systemd/network/10-dhcp.network" \
  --run-command "sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"

echo ">> Creating ${SPARE_GB}G spare disks (vdb, vdc, vdd) for storage labs..."
for d in b c d; do sudo qemu-img create -f qcow2 "$IMGDIR/$VM-vd$d.qcow2" "${SPARE_GB}G" >/dev/null; done

echo ">> Defining and starting the VM..."
sudo virt-install --name "$VM" --memory "$RAM_MB" --vcpus "$VCPUS" \
  --os-variant debian12 --machine pc \
  --disk path="$DISK",device=disk,bus=virtio \
  --disk path="$IMGDIR/$VM-vdb.qcow2",device=disk,bus=virtio \
  --disk path="$IMGDIR/$VM-vdc.qcow2",device=disk,bus=virtio \
  --disk path="$IMGDIR/$VM-vdd.qcow2",device=disk,bus=virtio \
  --network network=default,model=virtio \
  --graphics none --noautoconsole --import

echo ">> Installing the ops toolset over SSH (first boot may take a minute)..."
VM="$VM" USER_NAME="$USER_NAME" USER_PASS="$USER_PASS" "$HERE/install-tools.sh" \
  || echo "!! Toolset install was skipped/failed. Re-run later: provisioning/install-tools.sh"

echo
echo ">> Done. Connect with:  ./provisioning/lab-connect.sh"
echo ">> Find the VM IP with:  sudo virsh domifaddr $VM --source lease"
