# system_files/ — Overlay Layers

This directory contains the filesystem overlays applied to the OCI image. Three layers are merged at build time, with later layers winning on conflicts:

## Layers

### `shared/`
Applied to **all** variants: `bluefin`, `bluefin-lts`, `dakota`, `utah`, `iso`, and downstream forks.

**Rule:** A file goes in `shared/` if its absence would meaningfully degrade the experience on any variant, or if it provides infrastructure consumed by all variants (systemd units, udev rules, shell utilities, OEM hardware hooks, telemetry).

### `bluefin/`
Applied only to the **Bluefin GNOME desktop** variants. Contains:
- GNOME dconf defaults and locks
- Bluefin brand identity (icons, wallpapers via the `bluefin-branding` submodule)
- GNOME Shell extensions
- Bazaar app store configuration
- Bluefin-specific just recipes and Flatpak lists

**Rule:** A file goes in `bluefin/` if it is specific to the GNOME desktop, Bluefin product identity, or has no meaning on headless or non-GNOME variants.

### `nvidia/`
Applied to the **NVIDIA GPU** image variant. Contains only NVIDIA-specific runtime configuration: `ublue-nvidia-flatpak-runtime-sync` and its systemd unit.

**Rule:** A file goes in `nvidia/` if it only makes sense when an NVIDIA GPU is present.

## Shipped systemd units

`shared/usr/lib/systemd/`:

| Unit | Enabled by | Runs |
|---|---|---|
| `system/rechunker-group-fix.service` | `system-preset/00-rechunker-group-fix.preset` | Early boot, before `systemd-sysusers` |
| `system/uupd.timer`, `system/uupd-resume.timer`, `system/uupd-on-ac.service` | `system-preset/01-uupd.preset` | Background OS updates |
| `system/flatpak-appstream-refresh.service` | `system-preset/02-flatpak-appstream-refresh.preset` | Flatpak metadata refresh |
| `system/bluefin-countme.service` + `.timer` | `system-preset/03-bluefin-countme.preset` | Weekly, `Persistent=true`, `RandomizedDelaySec=12h` |
| `system/flatpak-preinstall.service` | — | Flatpak preinstall |
| `system/ublue-system-setup.service` | — | First-boot system hooks |
| `user/brew-preinstall.service` | `user-preset/01-brew-preinstall.preset` | Per-user, after `graphical-session.target` |
| `user/ublue-user-setup.service` | — | First-boot user hooks |

### `bluefin-countme` — weekly anonymous census

`shared/usr/libexec/bluefin-countme` is the client half of the CountMe census;
the endpoint and the data policy are documented in
[`docs/skills/image-registry.md`](../docs/skills/image-registry.md).

What the script does, in order:

1. Exits 0 immediately if any of `/etc/projectbluefin/countme/disabled`,
   `/etc/bluefin-countme-opt-out`, or `/etc/dakota-countme/disabled` exists.
   The `.service` and `.timer` carry the same three paths as
   `ConditionPathExists=!`, so opting out stops the timer as well as the script.
2. Seeds (or repairs, if non-numeric) an `epoch` timestamp under
   `$STATE_DIRECTORY` — `/var/lib/bluefin-countme` via `StateDirectory=`.
3. Exits 0 if `lastrun` is less than 604800 seconds old.
4. Buckets the install by age, Fedora-style: `1` for week 1, `2` for weeks 2–4,
   `3` for weeks 5–24, `4` beyond that.
5. Reads `image-name`, `image-flavor`, and `image-tag` from
   `/usr/share/ublue-os/image-info.json`. Exits 0 immediately if the image
   is not Dakota (`dakota*`). Reports with repo `dakota` (rendered as "Bluefin"
   by the first-party CountMe deployment).
6. Overrides the tag with the *booted* tag from `/run/ublue-os/booted-image`
   or `bootc status --json`, then normalises `stable|gts|lts` → `stable` and
   `testing|canary|next` → `testing`. A digest-pinned ref leaves the tag alone.
7. Sets `gamemode=1` from a gaming flavor/name or a gamescope wayland-session
   file.
8. `GET`s `https://countme.projectbluefin.io/metalink` with the repo, tag,
   flavor, gamemode, arch, and bucket as query parameters, and writes `lastrun`
   **only** on HTTP success — a failed request retries on the next timer fire.

The unit runs `Type=oneshot` under `DynamicUser=yes` and is gated on
`ConditionPathExists=/run/ostree-booted`, so it never fires in a container
build or on a non-ostree host. The request body and User-Agent carry no
hostname, MAC, machine ID, or user identifier — only the six fields above plus
`VERSION_ID` from `/etc/os-release`. The client IP is visible to the server as
it is for any HTTP request; what the service retains is its own policy, in
[`docs/skills/image-registry.md`](../docs/skills/image-registry.md).

Behavior is pinned by `tests/test_bluefin_countme.bats`.

## Build-time additions

The Containerfile's `build` stage writes generated artifacts into the layers
before the `ctx` scratch image assembles them:

- `shared/usr/share/{bash-completion/completions,zsh/site-functions,fish/vendor_completions.d}/` — `ujust` completions, generated from `just --completions` and `sed`-renamed
- `shared/usr/lib/udev/rules.d/` — YubiKey `70-u2f.rules` and the game-devices-udev rule set, fetched per-file at pinned commit SHAs with inline `sha256sum -c`
- `shared/usr/bin/umotd`, `shared/usr/bin/uwelcome` — Go binaries from the `umotd-build` and `uwelcome-build` stages
- `bluefin/usr/share/backgrounds/bluefin/` — wallpapers pulled from `ghcr.io/ublue-os/bluefin-wallpapers-gnome` (note: `ublue-os`, not `projectbluefin`), relocated out of `~/.local/share` by a `sed` over the `.xml` metadata
- `bluefin/etc/bazaar/*.png` — Bazaar banners, converted from the `bluefin-branding` submodule's `.jxl` sources by `djxl`

See [`docs/skills/containerfile/SKILL.md`](../docs/skills/containerfile/SKILL.md) for the stage details.

## OEM hardware

OEM-specific hooks, udev rules, and assets all live in `shared/` so they are present on every variant. Hooks detect hardware at runtime via DMI strings and exit immediately on non-matching hardware — runtime cost is negligible.

See [`docs/skills/oem-hardware-hooks/SKILL.md`](../docs/skills/oem-hardware-hooks/SKILL.md) for the OEM hook system.
