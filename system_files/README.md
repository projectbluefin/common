# system_files/ — Overlay Layers

This directory contains the filesystem overlays applied to the OCI image. Three layers are merged at build time, with later layers winning on conflicts:

## Layers

### `shared/`
Applied to **all** Bluefin variants: `bluefin`, `bluefin-lts`, `dakota`, `knuckle`, and any downstream fork.

**Rule:** A file goes in `shared/` if its absence would meaningfully degrade the experience on any variant, or if it provides infrastructure consumed by all variants (systemd units, udev rules, shell utilities, OEM hardware hooks).

### `bluefin/`
Applied only to the **Bluefin GNOME desktop** variants. Contains:
- GNOME dconf defaults and locks
- Bluefin brand identity (icons, wallpapers via the `bluefin-branding` submodule)
- GNOME Shell extensions
- Bazaar app store configuration
- Bluefin-specific just recipes and Flatpak lists

**Rule:** A file goes in `bluefin/` if it is specific to the GNOME desktop, Bluefin product identity, or has no meaning on headless or non-GNOME variants.

### `nvidia/`
Applied to the **NVIDIA GPU** image variant. Contains only NVIDIA-specific runtime configuration.

**Rule:** A file goes in `nvidia/` if it only makes sense when an NVIDIA GPU is present.

## Build-time additions

The Containerfile also copies generated artifacts into the layers:
- `shared/usr/share/ublue-os/` — ujust completions (from build stage)
- `shared/usr/lib/udev/rules.d/` — YubiKey U2F rules and game-devices-udev rules (fetched + SHA256-verified)
- `shared/usr/bin/` — umotd and uwelcome binaries (from build stages)

## OEM hardware

OEM-specific hooks, udev rules, and assets all live in `shared/` so they are present on every variant. Hooks detect hardware at runtime via DMI strings and exit immediately on non-matching hardware — runtime cost is negligible.

See `docs/skills/oem-hardware-hooks.md` for the OEM hook system.

## Ghostty SSH compatibility

The shared Ghostty profile enables `shell-integration-features = ssh-env,ssh-terminfo`
(Ghostty 1.2.0 or newer). With Ghostty shell integration loaded, SSH attempts to
install `xterm-ghostty` terminfo into the remote user's `~/.terminfo`, preserving
Ghostty's terminal capabilities. This requires local `infocmp` and remote `tic`.
If installation fails, SSH falls back to `xterm-256color`; local sessions keep
`xterm-ghostty`.

The profile is installed through `/etc/skel`, so this default only reaches new
homes. Existing users can add the setting to their own Ghostty configuration.
