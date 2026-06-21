# NUC7 BIOS reference (Talos nodes)

Standardized BIOS config for the headless NUC7 "Baby Canyon" nodes running Talos,
accessed over IP-KVM (TinyPilot in basement, GLKVM Comet in garage).

**Applies to:** `NUC7i3BNB` (metal-01/02/03/08/09), `NUC7i5BNB`/`NUC7i5BNH`
(metal-04/05/06). All share the Intel **Visual BIOS**, BIOS family `BNKBL357.86A`.

**Does NOT apply to:** metal-07 (NUC13, ASUS Aptio BIOS) and metal-10/11
(other-vendor boxes) — same *intent* below, different menus; configure by hand.

> Settings here were validated against the Intel NUC Visual BIOS Glossary, the
> NUC7 Technical Product Spec, and the Intel/ASUS power-management docs (see
> Sources). Visual BIOS top-level tabs: **Advanced, Cooling, Performance,
> Security, Power, Boot**.

---

## 0. Update the BIOS first

The latest is **0093** (Dec 2023); older units shipped on 0087. Flash 0093
**before** setting values — a newer BIOS can change defaults, so doing it after
risks partially resetting your settings.

Get the recovery `.bio` (e.g. `BN0093.bio`) from the
[Intel BNKBL357 download](https://www.intel.com/content/www/us/en/download/18838/bios-update-bnkbl357.html)
or the ASUS NUC support page, then build a USB stick and F7-flash it:

```bash
# 1. download the .bio (pass the direct URL) → talos/bios/
just talos download-bios "<direct-url-to/BN0093.bio>"

# 2. find your USB stick
diskutil list external physical

# 3. write it (destructive; prompts to confirm; refuses internal disks)
just burn bios talos/bios/BN0093.bio disk4
```

Flash: insert USB → power on → press **F7** repeatedly at POST → pick the `.bio`.
Do not cut power during the flash. The same USB/F7 flow applies to a custom
Integrator Toolkit `.bio` if you bake settings into the image instead of setting
them by hand.

---

## 1. Disable — unused consumer features

`Advanced → Devices → Onboard Devices` (NUC7 nests these under **Devices**;
newer NUCs drop that level to `Advanced → Onboard Devices`):

| Setting (exact label) | Value | Why |
| --- | --- | --- |
| **SDCard 3.0 Controller** | Disabled | Stops the RTS5229 `[10ec:5229]` correctable AER log flood; never used |
| **HD Audio** | Disabled | No speakers on a server |
| **WLAN** | Disabled | Wired-only; removes RF attack surface |
| **Bluetooth** | Disabled | Same as WLAN |
| **Enhanced Consumer IR** | Disabled | Remote-control receiver, useless headless |
| **HDMI CEC Control** | Disabled | TV-remote-over-HDMI; irrelevant via KVM |
| **Digital Microphone** | Disabled | N/A |

> **Leave Thunderbolt Support ENABLED fleet-wide.** The rear USB-C on the i5BNH
> is the Thunderbolt 3 port (doubles as USB 3.1); the GLKVM Comet connects
> through it, so disabling TB risks killing the KVM. The only reason to disable
> is physical DMA attack surface, which is moot for a home rack and already
> mitigated by VT-d (IOMMU) being enabled. The i3 control-plane boards may not
> expose the toggle at all.

Other: `Advanced → Devices → USB → Portable Device Charging Mode` → **Disabled**;
`Power → Deep Sleep / Deep S5` → **Disabled** (conflicts with reliable AC-restore
behavior). LED ring/lighting → Disabled if present (cosmetic).

## 2. KEEP ENABLED — landmines (disabling locks you out)

| Setting | Keep | If disabled… |
| --- | --- | --- |
| **LAN** (`Advanced → Devices → Onboard Devices → LAN`) | **ON** | Node unreachable — it's the only NIC. Sits right next to the toggles above; don't fumble it |
| **USB ports + USB Legacy** (`Advanced → Devices → USB`) | **ON** | KVM keyboard dies *and* can't boot Talos ISO via virtual media |
| **USB Boot** | **ON** | Can't provision/reinstall via KVM virtual media |
| **Intel Virtualization Technology** (`Security → Security Features`) | **ON** | Breaks container/VM workloads |
| **Intel VT for Directed I/O (VT-d)** (`Security → Security Features`) | **ON** | Harmless on; needed for any passthrough |
| **Intel Platform Trust Technology / PTT** (`Security → Security Features`) | **ON** | Leave on; enables future disk encryption at no cost |

> VT-x / VT-d / PTT are under **Security → Security Features**, NOT Advanced.

## 3. VERIFY (confirm, don't assume) — the important one

| Setting | Must be | Path |
| --- | --- | --- |
| **SATA Mode** | **AHCI** (not RAID / Intel RST / Optane) | `Advanced → Devices → SATA` |

Matters most for the Ceph workers (metal-04/05/06 + future 11/12/13): in
RAID/RST mode Talos may not see the Samsung 870 SATA OSD as a raw `/dev/sda`,
which Rook requires.

## 4. Talos compatibility

| Setting | Value | Path |
| --- | --- | --- |
| Secure Boot | **Disabled** | `Boot → Secure Boot` (standard Talos metal image isn't signed for SB) |
| Boot mode / CSM | **UEFI only** (Legacy off) | `Boot → Boot Configuration` |
| Fast Boot | **Disabled** | `Boot → Boot Configuration` — also part of the keyboard fix (forces full USB re-init) |
| Network / PXE boot | **Off** | `Boot → Boot Configuration` (not using PXE) |
| Boot order | Install disk (NVMe/SATA) first; keep USB available | `Boot → Boot Priority` |

## 5. Cooling

Headless rack nodes — noise is irrelevant, thermal headroom/longevity is not.
The garage is warmer/less stable than the basement, and the i5 Ceph workers see
sustained load (rebalance/scrub).

| Setting | Value | Path |
| --- | --- | --- |
| **Fan Control Mode** | **Cool** | `Cooling` tab |

Default is tuned for a quiet desktop; "Cool" runs the fan more aggressively.
Avoid "Quiet". "Fixed"/Full-Speed is needless fan wear. Leave the **Performance**
tab at default (Turbo + Hyper-Threading on) — these are 15W TDP parts; let the
fan handle heat, don't throttle the CPU.

Verify under load: `talosctl -n <ip> read /sys/class/thermal/thermal_zone0/temp`
(millidegrees C); keep sustained load under ~75-80°C.

## 6. Operational / power

| Setting | Value | Path |
| --- | --- | --- |
| **After Power Failure** | **Power On** | `Power → Secondary Power Settings` — auto-boot when AC returns (matters for the garage rack) |
| Wake on LAN from S4/S5 | Enabled (optional) | `Power → Secondary Power Settings` |

---

## KVM keyboard drops after boot

Symptom: keyboard works in BIOS but stops responding once Talos boots. This is
the firmware→Linux xHCI USB handoff, not a BIOS-config bug. Fixes:

1. **Fast Boot → Disabled** (§4) — forces full USB re-init so the KVM HID
   re-enumerates for the OS.
2. **Talos kernel arg** `usbcore.autosuspend=-1` — already set fleet-wide in
   `talos/machineconfig.yaml.j2` (`machine.install.extraKernelArgs`); applies on
   the next `apply-node` + reboot.
3. Plug the KVM into a **rear USB 2.0** port (avoid xHCI re-enumeration).
4. Keep the KVM's own firmware current.

## Notes

- Exact menu nesting shifts by BIOS generation. NUC7 puts device toggles under
  `Advanced → Devices → {Onboard Devices, USB, SATA}`; the labels above are
  verified. If a path reads slightly differently, it's within that section —
  verify SATA/USB/Boot paths on the first unit before trusting across the fleet.
- `metal-05` is a Wortmann-rebranded NUC7i5BNB (cosmetic SMBIOS strings only);
  hardware/BIOS identical.

## Sources

- Intel NUC Visual BIOS Glossary — menu structure / labels
- NUC7i3BN / NUC7i5BN Technical Product Specification
- <https://www.intel.com/content/www/us/en/support/articles/000095202/intel-nuc.html> (power management)
- <https://www.asus.com/support/faq/1052162/> (auto power-on after AC restore)
- <https://www.virten.net/2020/03/intel-nuc-recommended-bios-settings-for-vmware-esxi/> (validated device/Security paths)
- <https://www.intel.com/content/www/us/en/download/18838/bios-update-bnkbl357.html> (BIOS 0093 download)
