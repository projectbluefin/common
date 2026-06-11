---
name: dconf-consistency
description: "GSettings override and dconf lock file parity rules — must edit both files together for locked settings. Use when changing any GSettings key, dconf override, or lock file in system_files/."
metadata:
  type: procedure
---

# dconf Consistency

## The two-file rule

GSettings defaults live in two coordinated files:

| File | Purpose |
|---|---|
| `system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override` | Sets the default value |
| `system_files/bluefin/etc/dconf/db/distro.d/locks/01-bluefin-locked-settings` | Prevents users from changing it |

**Every locked key must exist in the override. Every override key that should not be user-overridable must be in the lock file.**

These two files must be edited together. Editing one without the other produces:
- Lock file references a missing key → dconf compile error on boot
- Override sets a value, lock file omits it → user can override it (silent regression)

## Adding a locked setting

1. Add the key + value to `zz0-bluefin-modifications.gschema.override`
2. Add the key path to `locks/01-bluefin-locked-settings`
3. Verify locally: `gschema.override` format requires `[schema]` section header, key = value

## Removing a locked setting

1. Remove from `locks/01-bluefin-locked-settings` first
2. Then remove from (or update) `zz0-bluefin-modifications.gschema.override`

## Adding an unlocked default

Only step 1 above — do **not** add to the lock file.

## dconf distro.d files

The numbered files in `system_files/bluefin/etc/dconf/db/distro.d/` set defaults and
keybindings. They are merged in numeric order. Gaps in numbering are fine. Do not renumber
existing files — it changes the merge order.

## Validation

`validate.yml` now includes an automated pre-merge parity check for `01-bluefin-locked-settings` against the `.override` files in `system_files/bluefin/usr/share/glib-2.0/schemas/`.

When changing locked settings, still verify locally when possible:

```bash
# Check the override compiles (requires glib2 tools)
glib-compile-schemas --strict system_files/bluefin/usr/share/glib-2.0/schemas/
```

The E2E `common` suite validates dconf state post-merge.

## Shared launchers for GNOME menu items

If a custom-command-menu entry and a desktop file should launch the same thing, prefer a shared helper under `system_files/bluefin/usr/bin/` instead of duplicating inline shell in both places. Update both the dconf entry and the `.desktop` file together so the shell menu and app launcher stay in sync.
