set quiet := true

bios_dir := justfile_dir() + '/talos/bios'
talos_dir := justfile_dir() + '/talos'

[private]
default:
  just -l burn

[doc('Write a NUC .bio to a FAT32 USB stick for F7 Express BIOS Update. disk = e.g. disk4 (macOS)')]
bios bio disk:
  #!/usr/bin/env bash
  set -euo pipefail
  bio="{{ bio }}"; disk="{{ disk }}"; disk="${disk#/dev/}"
  [[ -f "$bio" ]] || { just log error "BIOS file not found" file "$bio"; exit 1; }
  # Safety net: only touch external/removable media — never an internal disk.
  if ! diskutil info "$disk" | grep -qE 'Device Location: +External|Removable Media: +(Removable|Yes)'; then
    just log error "Refusing — not an external/removable disk" disk "$disk"; exit 1
  fi
  diskutil info "$disk" | grep -E 'Device Node|Device / Media Name|Disk Size|Device Location' || true
  gum confirm "ERASE $disk and write $(basename "$bio")?" --default=No || exit 0
  diskutil eraseDisk FAT32 NUCBIOS MBRFormat "$disk"
  cp "$bio" /Volumes/NUCBIOS/
  sync
  diskutil eject "$disk"
  just log info "BIOS USB ready — boot the NUC, press F7, pick $(basename "$bio")"

[doc('Write a Talos ISO to a USB stick (raw/bootable). disk = e.g. disk4 (macOS)')]
talos iso disk:
  #!/usr/bin/env bash
  set -euo pipefail
  iso="{{ iso }}"; disk="{{ disk }}"; disk="${disk#/dev/}"
  [[ -f "$iso" ]] || { just log error "ISO not found" file "$iso"; exit 1; }
  # Safety net: only touch external/removable media — never an internal disk.
  if ! diskutil info "$disk" | grep -qE 'Device Location: +External|Removable Media: +(Removable|Yes)'; then
    just log error "Refusing — not an external/removable disk" disk "$disk"; exit 1
  fi
  diskutil info "$disk" | grep -E 'Device Node|Device / Media Name|Disk Size|Device Location' || true
  gum confirm "ERASE $disk and write $(basename "$iso")?" --default=No || exit 0
  diskutil unmountDisk "/dev/$disk"
  just log info "Writing ISO raw (sudo; silent — Ctrl-T shows progress) ..."
  sudo dd if="$iso" of="/dev/r$disk" bs=4m
  sync
  diskutil eject "/dev/$disk"
  just log info "Talos USB ready — boot the node from it" file "$(basename "$iso")"
