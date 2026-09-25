---
name: systemd-user-units
version: "1.0"
last_updated: "2026-09-25"
id: systemd-user-units
one_line_purpose: Ship systemd user units and rootless quadlets from common, and toggle them per user.
entry_point: docs/skills/systemd-user-units.md
category: platform
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [systemd, quadlet, user-units, ujust, system_files]
description: >-
  systemd user services, presets, and rootless quadlet containers shipped by
  common. Use when adding or editing a unit under system_files/shared/, writing
  a ujust enable/disable toggle for one, or debugging why a unit starts anyway.
metadata:
  type: reference
---

# systemd user units and quadlets — projectbluefin/common

Covers the units this repo ships in `system_files/shared/`, how they get
enabled on the image, and the only reliable per-user way to switch them off.

## When to Use

- Adding or editing anything under `system_files/shared/usr/lib/systemd/user/`,
  `usr/lib/systemd/user-preset/`, or `usr/share/containers/systemd/users/`
- Writing a `ujust` recipe that enables, disables, or reports on such a unit
  (see `toggle-ffmpeg-thumbnailer` / `status-ffmpeg-thumbnailer` in
  [`shared.just`](../../system_files/shared/usr/share/ublue-os/just/shared.just))
- A user reports a unit still starting after they disabled it

## Where units live

| Path | What it is |
|---|---|
| `usr/lib/systemd/user/*.service` | Static user units. Image content, read-only at runtime. |
| `usr/lib/systemd/user-preset/*.preset` | `enable`/`disable` defaults applied when the unit is first seen (image install / first user creation). |
| `usr/lib/systemd/user/<target>.wants/<unit>` | Static pull-in symlink. Part of the image, not of the enable state. |
| `usr/share/containers/systemd/users/*.container` | Rootless quadlets. The quadlet generator turns `foo.container` into `foo.service` at user-manager start. |

Quadlet naming is the one thing to get right when writing `After=` lines or a
toggle: the generated unit is `<filename-stem>.service`, so
`ffmpeg-thumbnailer-nvidia.container` is `ffmpeg-thumbnailer-nvidia.service`,
regardless of the `ContainerName=` inside the file. Do not assume a `.container`
file can be masked by its own name.

## Enabling: presets, not `systemctl enable`

Downstream image repos do **not** run `systemctl --global enable`. Units are
enabled by shipping a preset line, e.g.
`usr/lib/systemd/user-preset/01-ffmpeg-thumbnailer.preset`:

```
enable ffmpeg-thumbnailer-daemon.service
```

Two consequences for anything you write in `common`:

- A unit that must start for every user needs either the preset **or** a static
  `wants/` symlink in the image — a `WantedBy=` line alone is inert until
  something enables the unit.
- Because enablement is image state, a per-user toggle cannot undo it with
  `systemctl --user disable`. See below.

## Disabling per user: mask, not disable

`systemctl --user disable <unit>` only removes symlinks the enable verb created.
It does **not** touch a static `usr/lib/systemd/user/<target>.wants/<unit>`
symlink, and for quadlet-generated units it has nothing to act on at all — the
generated `.service` has no install state systemctl can edit, so only the
generator decides whether it exists and what pulls it in.

`systemctl --user mask <unit>` writes a symlink to `/dev/null` into the user's
own unit directory (no `sudo`) and outranks the image and generator locations,
so systemd refuses to load the unit no matter what pulls it in. That is why the
thumbnailer toggle masks all three units — the daemon *and* both container
quadlets — instead of stopping them:

```bash
systemctl --user stop ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service
systemctl --user mask ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service
# later, to restore image behaviour:
systemctl --user unmask ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service
```

Re-enabling also needs `systemctl --user daemon-reload`, and starting the
container quadlets explicitly if thumbnails must work before the next login.
A mask is durable user state: it survives image updates until `unmask` (or
deleting the symlink) removes it.

Stop before mask, in that order: the daemon unlinks its socket on `SIGTERM`, so
masking a live unit can leave a stale socket path behind.

## Writing the toggle recipe

Recipe bodies are bash, so test them by extracting the body and stubbing
`systemctl` on `PATH` (see
[`shell-scripts/references/bats-patterns.md`](shell-scripts/references/bats-patterns.md)).
Two things to carry into the recipe:

- Resolve every unit through one array so stop/mask/start cannot drift apart,
  and probe for the unit (`systemctl --user cat <unit>`) before mutating
  anything — `shared.just` is also consumed by images that do not ship the
  thumbnailer, where the recipe must report "not installed" instead of
  masking a unit that does not exist.
- Never write `{{` in the body. `just` interpolates it before bash ever sees
  the script, and a `podman ps --format '{{.Status}}'` style argument fails to
  parse the entire recipe. Write the literal as `{{{{` if one is unavoidable.

## Red Flags

- A toggle that calls `systemctl --user disable` on a unit shipped in
  `usr/lib/systemd/user/` — the static `wants/` symlink keeps starting it
- Masking a quadlet's `.container` filename instead of the generated `.service`
- Assuming `systemctl --user cat <quadlet>.service` fails merely because the
  file is in `usr/share/containers/systemd/` — the generator makes the unit
  loadable at user-manager start, and `cat` is the right existence probe
- A recipe body containing `{{ ... }}`
- Documenting enablement as `systemctl --global enable`; presets own it

## Verification

Re-derive each fact on a live system rather than trusting this page:

```bash
# Real unit search path and its order for the user manager:
systemd-analyze --user unit-paths

# Enable state: "masked" is the state this skill's toggles produce.
systemctl --user is-enabled ffmpeg-thumbnailer-daemon.service

# Where a mask landed, and what it shadows:
ls -l "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/"

# What actually pulls a unit in (preset, static wants, or generator):
systemctl --user show -p LoadState -p UnitFileState -p WantedBy -p RequiredBy \
  ffmpeg-thumbnailer-daemon.service
grep -rn "ffmpeg-thumbnailer" system_files/shared/usr/lib/systemd/ \
  system_files/shared/usr/share/containers/systemd/
```

## See Also

- [`shell-scripts/SKILL.md`](shell-scripts/SKILL.md) — testing recipe bodies and shell scripts
- [`submodule-boundary.md`](submodule-boundary.md) — which `system_files/` tree a unit belongs in
- [`dconf-consistency.md`](dconf-consistency.md) — the same override-vs-lock pattern for desktop settings
