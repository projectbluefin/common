---
name: submodule-boundary
description: "system_files/shared/ is now directly editable in this repo — the aurorafin-shared submodule has been removed."
---

# system_files scope — what is editable where

## Summary

`system_files/shared/` is now a **directly tracked directory** in this repo. It was previously a read-only bind from the `aurorafin-shared` submodule, but that dependency has been severed. You can now edit files in `system_files/shared/` directly in PRs to this repo.

`system_files/bluefin/` remains the editable path for Bluefin-specific config.
`system_files/nvidia/` contains NVIDIA-specific overlays and is also directly tracked here.

## Editable paths

| Path | Editable? | Notes |
|---|---|---|
| `system_files/shared/**` | ✅ Yes | Directly tracked — edit here |
| `system_files/bluefin/**` | ✅ Yes | Bluefin-specific config |
| `system_files/nvidia/**` | ✅ Yes | NVIDIA overlay |
| `bluefin-branding/**` | ❌ No | Submodule — `projectbluefin/branding` |

## What changed

Previously, `system_files/shared/` was materialized from a `ublue-os/aurorafin-shared` git submodule. The `validate.yml` workflow enforced that `system_files/shared/` could not be edited directly. **That constraint is gone.** The submodule has been removed and the files are now owned here.

## Submodule that remains

Only `bluefin-branding` remains as a submodule:
```
bluefin-branding → projectbluefin/branding (wallpapers, logos)
```
