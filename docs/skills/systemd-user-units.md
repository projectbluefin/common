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

## Enabling: `[Install]` + the quadlet generator

Downstream image repos do **not** run `systemctl --global enable`. What starts
a unit here is one of three things, and it is worth checking which one before
writing a toggle:

- An `[Install] WantedBy=` line plus something that acts on it — a shipped
  `usr/lib/systemd/user-preset/*.preset` entry, or the user running
  `systemctl --user enable`. `ffmpeg-thumbnailer-daemon.service` takes this
  route: it ships `WantedBy=graphical-session.target default.target` and
  `common` ships no preset for it, so the `enable` branch of the toggle is what
  installs the wants symlink.
- A static `usr/lib/systemd/user/<target>.wants/<unit>` symlink baked into the
  image. `common` uses this for system timers (`timers.target.wants/`), not for
  the thumbnailer.
- The quadlet generator. `ffmpeg-thumbnailer.container` and
  `ffmpeg-thumbnailer-nvidia.container` carry no `[Install]` section at all;
  the generator materialises `<stem>.service` at user-manager start, but
  nothing in the image pulls those services in. The daemon only orders itself
  `After=` them, which does not start them, so the sole starter today is the
  `enable` branch of `ujust toggle-ffmpeg-thumbnailer`.

Two consequences for anything you write in `common`:

- A `WantedBy=` line alone is inert. If a unit must start for every user
  without a ujust opt-in, it needs a preset line or a static `wants/` symlink.
- A per-user toggle cannot rely on `systemctl --user disable`, because two of
  the three units have no install state at all. See below.

## Disabling per user: mask, not disable

`systemctl --user disable <unit>` only removes symlinks the enable verb
created. For the quadlet-generated units it has nothing to act on — the
generated `.service` has no install state systemctl can edit, so only the
generator decides whether it exists and what pulls it in. For the daemon it
does work, but it is not durable: a preset added downstream, or a later
`enable`, reinstates the wants symlink, and `disable` does nothing to stop a
unit another unit already pulled in.

`systemctl --user mask <unit>` writes a symlink to `/dev/null` into the user's
own unit directory (no `sudo`) and outranks the image and generator locations,
so systemd refuses to load the unit no matter what pulls it in. That is the
one mechanism that works uniformly for all three units, which is why the
thumbnailer toggle masks the daemon *and* both container quadlets instead of
stopping them:

```bash
systemctl --user stop ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service
systemctl --user mask ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service
# later, to restore image behaviour:
systemctl --user unmask ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service
```

Re-enabling also needs `systemctl --user daemon-reload`, and starting the
container quadlets explicitly if thumbnails must work before the next login.
Start them with `--no-block`: they carry `TimeoutStartSec=900` and pull a
111 MB image on first start, so a blocking `start` stalls the caller for
minutes. A mask is durable user state: it survives image updates until
`unmask` (or deleting the symlink) removes it.

Stop before mask, in that order: the daemon unlinks its socket on `SIGTERM`, so
masking a live unit can leave a stale socket path behind. A single
`systemctl --user stop a b c` is enough — argument order does not sequence
anything; the daemon's `After=` on the container units is what makes systemd
stop it first.

## Masking is not enough: the `environment.d` drop-in

The thumbnailer also ships a system `environment.d` drop-in that puts its shim
directory first in `XDG_DATA_DIRS` for video MIME types. That variable is read
by the user session at login, not by a unit, so masking the units does nothing
to it: the shim `.thumbnailer` entries keep winning and video thumbnails keep
failing to the masked daemon.

`environment.d` resolves same-named files by name across its search path, and
the user directory outranks `/usr/lib`, so writing an empty (comment-only) file
at the same name shadows the system drop-in completely:

```bash
ENV_OVERRIDE="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/10-ffmpeg-thumbnailer.conf"
mkdir -p "$(dirname "${ENV_OVERRIDE}")"
printf '# masks the system drop-in\n' > "${ENV_OVERRIDE}"   # disable
rm -f "${ENV_OVERRIDE}"                                      # enable
```

Two consequences for any toggle that follows this pattern:

- The override is durable user state, like a mask, and it takes effect at the
  next login rather than immediately. Say so in *both* toggle branches: removing
  the file on enable is as deferred as writing it on disable, so a user who
  enables mid-session sees active units and still no thumbnails until re-login.
- Report it. A user who unmasks the units by hand, without the toggle, still
  gets no thumbnails and has nothing pointing at the leftover file —
  `status-ffmpeg-thumbnailer` prints whether it is present for exactly that
  reason. The status recipe also short-circuits on the same "is it installed?"
  probe as the toggle, so the pair never disagrees about an absent thumbnailer.

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

- A toggle that calls `systemctl --user disable` on a quadlet-generated
  `.service` — there is no install state to remove, so nothing changes
- Masking a quadlet's `.container` filename instead of the generated `.service`
- Assuming `systemctl --user cat <quadlet>.service` fails merely because the
  file is in `usr/share/containers/systemd/` — the generator makes the unit
  loadable at user-manager start, and `cat` is the right existence probe
- A recipe body containing `{{ ... }}`
- A toggle that masks units but leaves a session-level `environment.d` drop-in
  in place, or a status recipe that never reports the override it wrote
- Documenting enablement as `systemctl --global enable`; presets, static
  `wants/` symlinks, or an explicit `systemctl --user enable` own it

## Verification

Re-derive each fact on a live system rather than trusting this page:

```bash
# Real unit search path and its order for the user manager:
systemd-analyze --user unit-paths

# Enable state: "masked" is the state this skill's toggles produce.
systemctl --user is-enabled ffmpeg-thumbnailer-daemon.service

# Where a mask landed, and what it shadows:
ls -l "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/"

# Whether a user environment.d override is shadowing the system drop-in:
ls -l "${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/"
systemd-analyze --user cat-config environment.d

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
