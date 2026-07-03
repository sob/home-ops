#!/bin/bash
# Runs ONCE on the Pi's first boot (invoked via cmdline.txt systemd.run, the
# same mechanism Raspberry Pi Imager uses). Turns a stock Raspberry Pi OS Lite
# into the Talos PXE server. Concrete values (SSH key, static IP, dnsmasq.conf,
# ipxe.efi) are baked into /boot/firmware/talos-pxe/ by build-image.sh.
#
# It is intentionally generic — nothing here is secret or host-specific.
set +e
exec >>/var/log/talos-pxe-firstrun.log 2>&1
echo "=== talos-pxe firstrun $(date -u) ==="

USERNAME="sob"
BOOT=/boot/firmware
[ -d "$BOOT" ] || BOOT=/boot          # pre-Bookworm layout
PAYLOAD="$BOOT/talos-pxe"

# --- login user (Bookworm needs a first user created) + key-only SSH ---
if [ -x /usr/lib/userconf-pi/userconf ]; then
  /usr/lib/userconf-pi/userconf "$USERNAME" '*'   # '*' = locked password (key-only)
elif ! id "$USERNAME" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$USERNAME"
  usermod -aG sudo "$USERNAME"
fi
install -d -m700 -o "$USERNAME" -g "$USERNAME" "/home/$USERNAME/.ssh"
install -m600 -o "$USERNAME" -g "$USERNAME" "$PAYLOAD/authorized_keys" "/home/$USERNAME/.ssh/authorized_keys"
systemctl enable --now ssh

# --- hostname ---
echo talos-pxe > /etc/hostname
sed -i 's/127.0.1.1.*/127.0.1.1\ttalos-pxe/' /etc/hosts 2>/dev/null

# --- static IP (NetworkManager keyfile; Bookworm default net stack) ---
install -D -m600 "$PAYLOAD/talos-pxe.nmconnection" \
  /etc/NetworkManager/system-connections/talos-pxe.nmconnection
nmcli connection reload 2>/dev/null

# --- dnsmasq (the PXE/TFTP server) ---
apt-get update
apt-get install -y --no-install-recommends dnsmasq
systemctl disable --now systemd-resolved 2>/dev/null   # free :53 (we set port=0 anyway)
install -D -m644 "$PAYLOAD/dnsmasq.conf" /etc/dnsmasq.conf
install -D -m644 "$PAYLOAD/ipxe.efi" /srv/tftp/ipxe.efi
systemctl enable dnsmasq

# --- make this a one-shot: drop the firstrun invocation from cmdline.txt ---
sed -i 's| systemd.run[^ ]*||g' "$BOOT/cmdline.txt"
rm -f "$BOOT/firstrun.sh"

echo "=== talos-pxe firstrun done; rebooting ==="
# systemd.run_success_action=reboot (set in cmdline.txt) handles the reboot.
