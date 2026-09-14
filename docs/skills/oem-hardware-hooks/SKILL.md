---
name: oem-hardware-hooks
version: "1.1"
last_updated: "2026-08-08"
id: oem-hardware-hooks
one_line_purpose: Add OEM hardware first-boot setup hooks safely.
entry_point: docs/skills/oem-hardware-hooks/SKILL.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [hardware, oem, first-boot, hooks, shellcheck]
description: >-
  OEM hardware first-boot setup hooks in projectbluefin/common. Use when
  adding hardware-specific setup, understanding hook directories and
  versioning contract, or applying shellcheck requirements.
metadata:
  type: reference
---

# oem-hardware-hooks — OEM Hardware First-Boot Setup in common

How to add, move, or maintain hardware-specific first-boot setup hooks
in `projectbluefin/common`. Covers the hook directories, the versioning
contract, shellcheck requirements, and what belongs here vs upstream.

---

## When to Use

- Adding new hardware-specific first-boot behavior to `projectbluefin/common`
- Migrating a hook from a downstream repo (bluefin, bluefin-lts) into common
- Debugging a hook that burned its stamp prematurely or never ran
- Adding a new OEM vendor to the data-driven `20-oem-brew.sh` hook

## When NOT to Use

- Adding Fedora/Bluefin-version-specific logic that should stay downstream
- Installing packages that depend on services only one variant ships
- Anything requiring `brew install --cask` without trust (use Brewfile)

---

## Hook directories

Two directories are scanned automatically at first boot — no registration needed:

### Rule of thumb for where to place desktop or session settings

- **Image default for all users** → `system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override`
- **Locked (users cannot override)** → update both the override and `system_files/bluefin/etc/dconf/db/distro.d/locks/01-bluefin-locked-settings`
- **One-time first-boot action for current user** → `system_files/shared/usr/share/ublue-os/user-setup.hooks.d/` with `version-script` contract
- Do not create a new GNOME schema override file for a single setting when the existing Bluefin override already exists.

| Directory | Runner | Runs as |
|---|---|---|
| `system_files/shared/usr/share/ublue-os/system-setup.hooks.d/` | `ublue-system-setup` (systemd system service) | root |
| `system_files/shared/usr/share/ublue-os/user-setup.hooks.d/` | `ublue-user-setup` (systemd user service) | current user |

Name scripts with a numeric prefix (`10-`, `20-`) to control execution order.

---

## The version-script contract

Every hook must begin with:
```bash
# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

version-script <name> <type> <version> || exit 0
```

- `<name>` — a stable slug (e.g. `framework`, `theming`)
- `<type>` — `system`, `user`, or `privileged` — must match the runner
- `<version>` — integer; bump when you want the hook to re-run on existing systems

**Critical when migrating:** use the **same** version number as the downstream hook. Bumping it re-runs the hook on every existing system on next boot.

**`version-script` must fire AFTER all preconditions pass** — the stamp is written before your hook logic runs. See [`references/hook-patterns.md`](references/hook-patterns.md) for the canonical safe pattern and anti-pattern.

---

## Shellcheck requirement

CI runs `shellcheck -e SC2207` on all `*.sh` files in `system_files/`.
Always suppress SC1091 inline:

```bash
# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh
```

---

## What belongs in common vs downstream

**Move to common when the hook:**
- Has no Fedora/Bluefin-version-specific dependency
- Should apply to ALL variants including bluefin-lts
- Is pure hardware detection (DMI vendor/product, CPU vendor, BIOS version)

**Leave in the downstream repo when the hook:**
- Depends on packages or services only that variant ships
- Uses `brew install --cask` (depends on tap trust being configured first)
- Requires dconf keys only present in one variant's GNOME extension set

---

## Hardware currently in common

| Hook | Type | What it does |
|---|---|---|
| `system-setup.hooks.d/10-framework.sh` | system | Intel Framework keyboard karg; Framework 13 Ryzen 7040 suspend fix; AMD 3.5mm jack (kernel-aware) |
| `system-setup.hooks.d/11-asus.sh` | system | Enables asusd.service + asus-shutdown.service once asusctl is installed |
| `user-setup.hooks.d/10-theming.sh` | user | Framework scroll/font tweaks; Thelio Astra Ampere logo (non-brew vendors) |
| `user-setup.hooks.d/20-oem-brew.sh` | user | Generic OEM brew install + logo set (data-driven) |
| `user-setup.hooks.d/12-framework-color.sh` | user | Assigns factory ICC color profiles to Framework 13/16 displays via colormgr |

---

## Red Flags

- Calling `version-script` before checking transient preconditions (permanently burns the stamp)
- Bumping the version number when migrating a hook from downstream (causes re-run on all existing machines)
- Dropping un-scoped WirePlumber snippets into `system_files/shared/usr/share/wireplumber/wireplumber.conf.d/` (hardware quirks must explicitly match `device.vendor.id` and `device.product.id` so they only affect target hardware)
- Assuming `hardware-profiles/` loader from bazzite works in stock bluefin WirePlumber

---

## Verification

Before closing any OEM hook PR:

- [ ] `shellcheck -e SC2207` passes on all modified `*.sh` files
- [ ] `version-script` called **after** all transient preconditions are checked
- [ ] Version number matches downstream when migrating (not bumped)
- [ ] `bluefin-lts` path structure confirmed (`system_files/usr/share/...` — no `shared/` prefix)
- [ ] `just check` and `pre-commit run --all-files` pass clean

---

## References

| Reference | Description |
|---|---|
| [`references/hook-patterns.md`](references/hook-patterns.md) | version-script safe/anti-patterns; migrating a hook from bluefin to common; kernel-aware modprobe fixes; colormgr subcommands |
| [`references/oem-brew.md`](references/oem-brew.md) | OEM brew hook data-driven pattern; adding a new OEM vendor; OEM directories table; WirePlumber rules; known gaps |
