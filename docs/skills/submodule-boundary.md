---
name: submodule-boundary
description: "system_files/shared/ is read-only (aurorafin-shared submodule) — editable scope is system_files/bluefin/ only."
---

# Submodule Boundary

## What is read-only and why

`system_files/shared/` is materialized from the `aurorafin-shared` git submodule
(`ublue-os/aurorafin-shared`). The files appear in the working tree and look editable,
but **direct edits here are rejected by CI** (`validate.yml` → "Check submodule drift").

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

## Scope of shared/ content

`system_files/shared/` includes:
- `usr/share/ublue-os/just/` — ujust recipes shared across Aurora, Bluefin, and Dakota
- `usr/share/ublue-os/homebrew/` — Brewfiles
- Shell config, udev rules, and system service units common to all variants

Changes to any of these for **all** variants go upstream. Changes **only for Bluefin** go in
`system_files/bluefin/`.
