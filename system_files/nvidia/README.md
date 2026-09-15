# system_files/nvidia/ — NVIDIA Overlay

This layer is intended to be applied on top of `shared/` and `bluefin/` for the NVIDIA GPU
image variant.

> **Status: not consumed.** The `Containerfile` ctx stage publishes `/system_files/nvidia`,
> but no downstream image copies it — `projectbluefin/bluefin` (`Containerfile:48-49`),
> `projectbluefin/bluefin-lts` (`Containerfile:17-18`) and `projectbluefin/utah`
> (`Containerfile:66-67`) copy `/system_files/shared` and `/system_files/bluefin` only, and
> nothing in the org enables `ublue-nvidia-flatpak-runtime-sync.service`. Files added here
> reach no image. See common#1124 before relying on this path.

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
