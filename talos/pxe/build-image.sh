#!/usr/bin/env bash
# Bake a flashable Raspberry Pi OS image that boots as the Talos PXE server.
# Entry point is `just talos pxe-image`. macOS-only (uses hdiutil to write the
# image's FAT boot partition — no loop-mount/root needed); Docker is used only
# to cross-build the amd64 iPXE loader.
#
#   just talos pxe-image
#   PI_IP=10.1.100.99/24 SSH_PUBKEY=~/.ssh/id_ed25519.pub  just talos pxe-image
#
# Output: talos/pxe/dist/talos-pxe.img
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$here/out"; dist="$here/dist"; mkdir -p "$out" "$dist"

PI_IP="${PI_IP:-10.1.100.99/24}"; PI_GW="${PI_GATEWAY:-10.1.100.1}"; PI_DNS="${PI_DNS:-10.1.100.1}"
PUBKEY="${SSH_PUBKEY:-$HOME/.ssh/id_ed25519.pub}"
img="$dist/talos-pxe.img"

[ "$(uname)" = Darwin ] || { echo "pxe-image uses hdiutil (macOS); on Linux use loop mounts" >&2; exit 1; }
[ -f "$PUBKEY" ] || { echo "SSH public key not found: $PUBKEY (set SSH_PUBKEY=...)" >&2; exit 1; }
command -v docker >/dev/null || { echo "docker is required (to build the iPXE loader)" >&2; exit 1; }

# 1) render config, 2) cross-build the amd64 iPXE loader (https + boot.ipxe embedded)
"$here/render.sh"
docker build --platform=linux/amd64 -f "$here/Dockerfile.ipxe" --target export \
  --output "type=local,dest=$out" "$here"
[ -f "$out/ipxe.efi" ] || { echo "ipxe.efi build produced no output" >&2; exit 1; }

# 3) fetch + decompress Raspberry Pi OS Lite (arm64)
if [ ! -f "$img" ] || [ "${REFETCH:-0}" = 1 ]; then
  echo "Downloading Raspberry Pi OS Lite (arm64)…"
  curl -fL "https://downloads.raspberrypi.com/raspios_lite_arm64_latest" -o "$dist/raspios.img.xz"
  echo "Decompressing…"
  xz -dc "$dist/raspios.img.xz" > "$img"
fi

# 4) assemble the first-boot payload
rm -rf "$out/payload"; mkdir -p "$out/payload"
cp "$PUBKEY"           "$out/payload/authorized_keys"
cp "$here/dnsmasq.conf" "$out/payload/dnsmasq.conf"
cp "$out/ipxe.efi"     "$out/payload/ipxe.efi"
{
  printf '%s\n' "[connection]" id=talos-pxe type=ethernet interface-name=eth0 autoconnect=true
  printf '%s\n' "[ipv4]" method=manual "addresses=$PI_IP" "gateway=$PI_GW" "dns=$PI_DNS"
  printf '%s\n' "[ipv6]" method=disabled
} > "$out/payload/talos-pxe.nmconnection"

# 5) inject payload + firstrun hook into the FAT boot partition
attach="$(hdiutil attach -imagekey diskimage-class=CRawDiskImage "$img")"
dev="$(printf '%s\n' "$attach" | awk '/FDisk_partition_scheme/{print $1; exit}')"
boot="$(printf '%s\n' "$attach" | awk '/Windows_FAT_32|DOS_FAT_32/{for(i=1;i<=NF;i++) if($i ~ /^\/Volumes\//){print $i; exit}}')"
trap 'hdiutil detach "$dev" >/dev/null 2>&1 || true' EXIT
[ -n "$boot" ] || { echo "FAT boot partition not found in image" >&2; exit 1; }

rm -rf "$boot/talos-pxe"; mkdir -p "$boot/talos-pxe"
cp "$out"/payload/* "$boot/talos-pxe/"
cp "$here/firstrun.sh" "$boot/firstrun.sh"
line="$(tr -d '\n' < "$boot/cmdline.txt" | sed 's| systemd.run[^ ]*||g')"
printf '%s systemd.run=/boot/firmware/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target\n' \
  "$line" > "$boot/cmdline.txt"

sync; hdiutil detach "$dev" >/dev/null; trap - EXIT
echo "Baked $img  (Pi ${PI_IP}, sob + $(basename "$PUBKEY"), $(grep -c '^dhcp-host=' "$here/dnsmasq.conf") nodes)"
