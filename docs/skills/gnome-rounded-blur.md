---
name: gnome-rounded-blur
version: "1.0"
last_updated: 2026-09-29
id: gnome-rounded-blur
one_line_purpose: Keep the Blur My Shell GNOME defaults and the gnome-rounded-blur runtime library in agreement.
entry_point: docs/skills/gnome-rounded-blur.md
category: product
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [gnome, blur-my-shell, rounded-blur, mutter, system_files, gsettings]
description: >-
  Use when touching the Blur My Shell GSettings defaults, or when adding,
  removing or debugging the gnome-rounded-blur library that draws the rounded
  corners on dock and popup blur. Covers common's config layer versus the
  base image that installs it.
metadata:
  type: reference
---

# gnome-rounded-blur — rounded blur for Blur My Shell

## What the library is

`gnome-rounded-blur` (upstream `kancko/gnome-rounded-blur`) builds
`libgnome-rounded-blur.so`. The Blur My Shell extension
(`blur-my-shell@aunetx`) loads it at runtime; with it present the extension
punches a rounded mask around the blurred surface, so the dock and the shell
popups (Quick Settings, the calendar, the volume/brightness OSD) keep the
corners of the panel radius while still being blurred.

Without the library Blur My Shell degrades to one of two shapes, and both were
the original complaint in [#1053](https://github.com/projectbluefin/common/issues/1053):

- dynamic blur with square corners, or
- static (non-following) blur that keeps the rounded shape but does not track
  the windows behind it.

## The split: who does what

| Concern | Owner | Where |
|---|---|---|
| GSettings defaults for the extension | `projectbluefin/common` | `system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override` |
| Installing `gnome-rounded-blur` | the base image | `ublue-os/bluefin` `build_files/base/04-packages.sh` (merged via ublue-os/bluefin#4899) |
| Building the library for GNOME OS | `projectbluefin/dakota` | BuildStream element — **not implemented** |

`common` is the shared configuration/OCI layer. It ships no RPMs and runs no
package manager, so the library itself is **not** added here; it is pulled in
by the base image that the extension runs on. Do not try to vendor a built
`libgnome-rounded-blur.so` into the `Containerfile` — a raw `.so` dropped into
`/usr/lib64` bypasses rpm-ostree/`bootc` package management and pins the
library to one mutter ABI, which would break the other variants the moment any
of them moves its GNOME version.

## Current GNOME defaults

`system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override`:

```ini
[org.gnome.shell.extensions.blur-my-shell.dash-to-dock]
blur=true

[org.gnome.shell.extensions.blur-my-shell.popup]
blur=true
```

Both surfaces are blurred. `popup` was `false` until the base images started
carrying `gnome-rounded-blur`; it is `true` now because the rounded mask the
library provides is exactly what makes a blurred popup look intentional rather
than like a rectangle pasted over Quick Settings.

Neither key is dconf-locked — users are expected to be able to turn popup blur
off. If you ever lock one, follow the two-file rule in
[`dconf-consistency.md`](dconf-consistency.md): the lock file
(`system_files/bluefin/etc/dconf/db/distro.d/locks/01-bluefin-locked-settings`)
must be edited in the same PR as the override.

> **Precedence on Fedora bluefin (note, not a fault of this PR).** `ublue-os/bluefin`
> also ships `zz1-bluefin-extensions.gschema.override` and a dconf database entry
> in `distro.d/05-blur-my-shell-extension` that set `popup blur=false`. Both
> sort **after** this `zz0-…` override and the dconf database wins over schema
> defaults, so the `true` written here is currently masked on Fedora bluefin
> until those upstream overrides are removed in the same release. On
> `bluefin-lts` (no `zz1`, no `distro.d/05-…`) and on `dakota` (the library is
> not yet built, see below), this override is the effective value.

## Verifying locally

```bash
# On a running bluefin / bluefin-lts image
rpm -q gnome-rounded-blur
ls -l /usr/lib64/libgnome-rounded-blur.so*
gsettings get org.gnome.shell.extensions.blur-my-shell.popup blur
```

If `rpm -q` fails, the blur will render without rounded corners — that is a
missing base-image package, not a `common` config bug. If the gsettings read
returns `false`, the override did not compile; check
`/usr/share/glib-2.0/schemas/` was overlaid and that
`glib-compile-schemas` ran after the overlay.

Regression coverage for the defaults lives in
`tests/test_blur_my_shell.bats`.

## Rules

- Never add `gnome-rounded-blur` to a `common` package list; there is none, and
  adding one would silently do nothing.
- Changing either `blur-my-shell` key means changing the comment above it and
  re-running `tests/test_blur_my_shell.bats`.
- If the library is ever dropped from a base image, set `popup blur=false`
  again in the same PR — an unrounded popup blur is the regression this skill
  exists to prevent.
- Dakota is still unrounded: the BuildStream element that would build
  `gnome-rounded-blur` for GNOME OS has not been written. That gap belongs in
  `projectbluefin/dakota`, not here.

## See also

- [`dconf-consistency.md`](dconf-consistency.md) — the override/lock two-file rule.
- [`submodule-boundary.md`](submodule-boundary.md) — what belongs in `system_files/shared/` vs `system_files/bluefin/`.
