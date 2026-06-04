---
name: submodule-boundary
description: "system_files/shared/ is read-only (aurorafin-shared submodule) — editable scope is system_files/bluefin/ only."
---

# Submodule Boundary

## What is read-only and why

`system_files/shared/` is materialized from the `aurorafin-shared` git submodule
(`ublue-os/aurorafin-shared`). The submodule is not initialized in the working tree by
default — `system_files/shared/` may not even exist as a local directory.

**Critical:** the `Containerfile` copies from `aurorafin-shared/system_files/shared/`
(the submodule), **not** from a local `system_files/shared/` directory. Any files written
to the local `system_files/shared/` path are **silently ignored by the build**.

`system_files/bluefin/` is the correct place for Bluefin-specific config. Edit here freely.

## Rule

| Path | Editable? | Where to make changes |
|---|---|---|
| `system_files/shared/**` | ❌ No | Open a PR in `ublue-os/aurorafin-shared` |
| `system_files/bluefin/**` | ✅ Yes | Edit directly in this repo |
| `bluefin-branding/**` | ❌ No | Open a PR in `projectbluefin/branding` |

## Local verification

```bash
git diff --exit-code -- aurorafin-shared
```

Zero output = clean. Any output = you have uncommitted changes to the submodule that will
fail the CI drift check.

## CI gate

`validate.yml` step "Check submodule drift (aurorafin-shared)" runs `git diff --exit-code -- aurorafin-shared`
and prints a clear error if the submodule has been manually edited.

## Specific files that have moved upstream (as of #395)

These files **no longer exist** in this repo — they are owned by `ublue-os/aurorafin-shared`:

| File | Path in aurorafin-shared |
|---|---|
| `apps.just` | `system_files/shared/usr/share/ublue-os/just/apps.just` |
| `default.just` | `system_files/shared/usr/share/ublue-os/just/default.just` |
| `ublue-bling` | `system_files/shared/usr/bin/ublue-bling` |

Any PR that modifies these paths in this repo will hit a `modify/delete` conflict on rebase
because main deleted them when #395 wired the submodule. Leave a comment telling the author
to submit upstream. **Do not skip/drop these commits silently** — the fix still needs to land
somewhere.

## Upstream policy — ublue-os repos

**Agents must never file issues or PRs in `ublue-os/*` repos.** If a change requires
`ublue-os/aurorafin-shared`, tell the human contributor to report it there manually.

When you encounter a PR that touches `system_files/shared/`, leave a comment explaining
the boundary and close the loop — do not attempt to create the upstream PR yourself.
