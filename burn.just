set quiet := true

[private]
default:
  just -l burn

# ─── shared helpers ─────────────────────────────────────────────────────────

# Safety net: only ever touch external/removable media, never an internal disk.
# Also prints what the disk actually is, so the confirm prompt is an informed one.
[private]
guard disk:
  #!/usr/bin/env bash
  set -euo pipefail
  disk="{{ disk }}"; disk="${disk#/dev/}"
  if ! diskutil info "$disk" | grep -qE 'Device Location: +External|Removable Media: +(Removable|Yes)'; then
    just log error "Refusing — not an external/removable disk" disk "$disk"; exit 1
  fi
  diskutil info "$disk" | grep -E 'Device Node|Device / Media Name|Disk Size|Device Location' || true

# Write a bootable image raw. Used by every ISO-based target (Talos, vendor
# firmware updaters) — they all just need the image dd'd to the stick.
[private]
raw img disk kind hint:
  #!/usr/bin/env bash
  set -euo pipefail
  img="{{ img }}"; disk="{{ disk }}"; disk="${disk#/dev/}"
  [[ -f "$img" ]] || { just log error "Image not found" file "$img"; exit 1; }
  just burn guard "$disk"
  gum confirm "ERASE $disk and write $(basename "$img")?" --default=No || exit 0
  diskutil unmountDisk "/dev/$disk"
  just log info "Writing image raw (sudo; silent — Ctrl-T shows progress) ..."
  sudo dd if="$img" of="/dev/r$disk" bs=4m
  sync
  diskutil eject "/dev/$disk"
  just log info "{{ kind }} USB ready — {{ hint }}" file "$(basename "$img")"

# ─── targets ────────────────────────────────────────────────────────────────

[doc('Write a Talos ISO to a USB stick (raw/bootable). disk = e.g. disk4 (macOS)')]
talos iso disk:
  just burn raw "{{ iso }}" "{{ disk }}" "Talos" "boot the node from it"

[doc('Write a NUC BIOS .bio to a FAT32 USB stick for F7 Express BIOS Update. disk = e.g. disk4 (macOS)')]
nuc bio disk:
  #!/usr/bin/env bash
  set -euo pipefail
  bio="{{ bio }}"; disk="{{ disk }}"; disk="${disk#/dev/}"
  [[ -f "$bio" ]] || { just log error "BIOS file not found" file "$bio"; exit 1; }
  just burn guard "$disk"
  gum confirm "ERASE $disk and write $(basename "$bio")?" --default=No || exit 0
  # Intel Express BIOS Update wants a plain FAT32 stick with the .bio on it,
  # NOT a raw image — hence this target does not use the `raw` helper.
  diskutil eraseDisk FAT32 NUCBIOS MBRFormat "$disk"
  cp "$bio" /Volumes/NUCBIOS/
  sync
  diskutil eject "$disk"
  just log info "BIOS USB ready — boot the NUC, press F7, pick $(basename "$bio")"

[doc('Write a Samsung SSD firmware ISO to a USB stick (raw/bootable). disk = e.g. disk4 (macOS)')]
samsung iso disk:
  just burn raw "{{ iso }}" "{{ disk }}" "Samsung firmware" "boot the node holding the drive and follow the updater"
