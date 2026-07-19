---
name: mime-defaults
version: "1.0"
last_updated: 2026-07-19
tags: [mime, xdg, defaults, system_files]
description: "Shared MIME default-application configuration for Bluefin variants. Use when adding or changing default apps for file types in system_files/bluefin/etc/xdg/mimeapps.list."
metadata:
  type: reference
---

# MIME Default Applications — projectbluefin/common

## Where the config lives

`system_files/bluefin/etc/xdg/mimeapps.list` is the shared MIME default-application layer for Bluefin variants that consume `system_files/bluefin/`:

- **bluefin** — `Containerfile` copies `system_files/bluefin`
- **bluefin-lts** — `Containerfile` copies `system_files/bluefin`
- **dakota** — BuildStream-based, inherits `gnome-build-meta` defaults; intentionally out of scope for this file

## Why this layer

Per the freedesktop.org MIME-Apps specification, default applications are resolved in precedence order:

1. `~/.config/mimeapps.list` (user config, highest)
2. `$XDG_CONFIG_DIRS/mimeapps.list` (`/etc/xdg/mimeapps.list` — this file)
3. `$XDG_DATA_DIRS/applications/mimeapps.list` (e.g. `/usr/share/applications/mimeapps.list`, packaged defaults)

`/etc/xdg/mimeapps.list` therefore overrides the Fedora-packaged defaults without touching per-user config.

## Adding a new default

1. Confirm the target app is shipped OOTB for the consuming variants.
   - Flatpak OOTB set: `testsuite/tests/smoke/features/flatpak_permissions.feature`
   - Launched app smoke tests: `testsuite/tests/smoke/features/gnome_apps.feature`
2. Verify the app's `.desktop` `MimeType=` line actually declares the MIME type.
   - Loupe source: `data/meson.build` and `data/org.gnome.Loupe.desktop.in.in` in GNOME/loupe
   - Showtime source: `data/org.gnome.Showtime.desktop.in` in GNOME/showtime
3. Add one `mime/type=app-id.desktop` line per type under `[Default Applications]`.
4. Keep entries alphabetically sorted.
5. Run `just check` and any repo-defined tests before committing.

## Current mappings

| MIME type | Default app | Notes |
|---|---|---|
| `application/pdf` | `org.gnome.Papers.desktop` | document viewer |
| `application/vnd.appimage` | `noop.desktop` | intentionally no-op |
| `application/vnd.flatpak.ref` | `io.github.kolunmi.Bazaar.desktop` | Flatpak ref installer |
| `image/*` (png, jpeg, gif, webp, svg+xml, bmp, tiff, avif, heic, jxl) | `org.gnome.Loupe.desktop` | shipped OOTB |
| `video/*` (mp4, webm, x-matroska, quicktime, mpeg, ogg, 3gpp, mp2t, x-flv, x-m4v, x-msvideo, x-ms-wmv) | `org.gnome.Showtime.desktop` | shipped OOTB |

## Testsuite alignment

`projectbluefin/testsuite/tests/smoke/features/xdg_open.feature` validates defaults via `xdg-mime query default`. Step implementations in `tests/smoke/features/steps/steps.py` whitelist acceptable desktop files:

- Image viewers: `org.gnome.Loupe.desktop`, `eog.desktop`, `gthumb.desktop`, `shotwell.desktop`
- Video players: `org.gnome.Showtime.desktop`, `io.github.celluloid_player.Celluloid.desktop`, `totem.desktop`, `vlc.desktop`, `mpv.desktop`

A default entry only satisfies the test if its desktop ID is in the matching whitelist. `xdg-mime`/gio also skips defaults whose `.desktop` file is absent, so the Flatpak must be seeded in the test VM for the query to return the expected ID.

## Verification

```bash
# Confirm the file is valid ini-style and entries are sorted
just check

# After building the image, inside a VM/container with the Flatpak exported:
XDG_DATA_DIRS=/var/lib/flatpak/exports/share:/usr/local/share:/usr/share \
  xdg-mime query default image/png
# expected: org.gnome.Loupe.desktop
```
