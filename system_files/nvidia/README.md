# system_files/nvidia/ — NVIDIA Overlay

This layer is applied on top of `shared/` and `bluefin/` only for the NVIDIA GPU image variant.

## Current contents

- `usr/lib/systemd/system/` — NVIDIA-specific systemd unit(s)
- `usr/libexec/` — `ublue-nvidia-flatpak-runtime-sync` script

## Adding NVIDIA-specific configuration

If adding new NVIDIA-specific files, follow the standard Linux layout:

| Config type | Path |
|---|---|
| Systemd units | `usr/lib/systemd/system/` |
| Udev rules | `usr/lib/udev/rules.d/` (use `60-` prefix — platform workaround range) |
| Modprobe config | `usr/lib/modprobe.d/` |
| First-boot hooks | `usr/share/ublue-os/system-setup.hooks.d/` |
| Scripts / helpers | `usr/libexec/` |

See `docs/skills/oem-hardware-hooks.md` for how to write first-boot hooks.
