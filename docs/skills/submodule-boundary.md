---
name: submodule-boundary
version: "1.0"
last_updated: "2026-06-23"
id: submodule-boundary
one_line_purpose: Decide where a system_files change belongs across variants.
entry_point: docs/skills/submodule-boundary.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [submodules, git, architecture]
description: >-
  system_files scope boundary. Use when editing system_files/shared/,
  bluefin/, nvidia/, or deciding where a system file change belongs.
metadata:
  type: reference
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

## Local testing without a full build

Use `just overlay` to test `system_files/` changes as a systemd-sysext on a running Bluefin system, without building the full OCI image. See [`containerfile/SKILL.md`](containerfile/SKILL.md) for the full recipe, SELinux requirements, and activation steps.

## Dakota exclusion pattern

`system_files/shared/` flows into **bluefin, bluefin-lts, and dakota** via the common OCI context. Dakota's `elements/bluefin/common.bst` does a plain `cp -r system_files/shared/usr/` — it receives everything.

If you add a file to `system_files/shared/` that should **not** appear in dakota (e.g., a migration aid that only applies to users rebasing from legacy-rechunk images), add explicit `rm -f` lines to `dakota/elements/bluefin/common.bst` immediately after the copy block:

```yaml
# Dakota is a fresh BuildStream image — strip files that only apply to
# users migrating from legacy ublue-os/rechunk-based images.
rm -f "%{install-root}%{prefix}/bin/rechunker-group-fix"
rm -f "%{install-root}%{prefix}/lib/systemd/system/rechunker-group-fix.service"
rm -f "%{install-root}%{prefix}/lib/systemd/system-preset/00-rechunker-group-fix.preset"
```

**Current exclusions in `common.bst`:** `rechunker-group-fix` (script + service + preset) — migration aid for legacy rechunk-based image rebases; not needed on a fresh dakota install.

## rechunker-group-fix — architecture and fix history

### What it does

`rechunker-group-fix` ensures that users rebasing from images built with `nss-altfiles` (groups stored in `/usr/lib/group`) do not break their gshadow file when switching to an image that uses `/etc/group`. Without it, missing gshadow entries cause black screens and non-booting systems.

Key files (all live in `system_files/shared/`):
- `usr/bin/rechunker-group-fix` — script that syncs group→gshadow entries
- `usr/lib/systemd/system/rechunker-group-fix.service` — service that runs the script at boot
- `usr/lib/systemd/system-preset/00-rechunker-group-fix.preset` — enables the service on install

### Service ordering (critical — do not change without understanding this)

As of [common#530](https://github.com/projectbluefin/common/pull/530), the service must run with:

```ini
DefaultDependencies=no
Wants=local-fs.target
After=local-fs.target
After=bootc-sysusers-shadow-sync.service
Before=systemd-sysusers.service
```

**Why:** `systemd-sysusers` is what fails if gshadow is corrupt. The service must run *before* sysusers, not after. `bootc-sysusers-shadow-sync.service` is the upstream fix shipped in bootc ≥1.16 ([bootc#2207](https://github.com/bootc-dev/bootc/pull/2207), merged May 2025); our service must run after it so they coexist correctly. `DefaultDependencies=no` is required for any early-boot unit.

### flock on gshadow writes (required)

The script wraps all gshadow writes in `flock -x 9` to prevent corruption from concurrent access:

```bash
(
    flock -x 9
    while IFS=: read -r group_name _rest; do
        grep -q "^${group_name}:" "$GSHADOW_FILE" 2>/dev/null || \
            printf '%s:!*::\n' "$group_name" >> "$GSHADOW_FILE"
    done < "$GROUP_FILE"
) 9>>"${GSHADOW_FILE}"
```

Do not remove the flock — concurrent sysusers runs can corrupt the file.

### Repo-level duplication history

**bluefin** previously had its own copy of these files in `system_files/shared/`, which *shadowed* common's version and prevented common's fixes from taking effect. This was removed in [bluefin#439](https://github.com/projectbluefin/bluefin/pull/439).

**bluefin-lts** has never had its own copy — it has always deferred to common. No removal needed.

**dakota** actively strips these files (see exclusion pattern above) since it is a fresh BuildStream image and the migration path does not apply.

**Future agents:** If you need to change the rechunker service ordering or script behavior, edit only `system_files/shared/` in this repo. Check that no consuming repo (bluefin, bluefin-lts) has re-introduced a shadowing copy before declaring the fix applied.
