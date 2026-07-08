---
name: dconf-consistency
version: "1.0"
last_updated: 2026-06-23
tags: [dconf, gnome, configuration]
description: "GSettings override and dconf lock file parity rules — must edit both files together for locked settings. Use when changing any GSettings key, dconf override, or lock file in system_files/."
metadata:
  type: procedure
---

# dconf Consistency

## Default location for desktop and GNOME settings

When changing a desktop or GNOME default in this repo, start here:

- `system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override` for GSettings defaults
- `system_files/bluefin/etc/dconf/db/distro.d/locks/01-bluefin-locked-settings` for keys that must be locked against user changes

This is the canonical place for Bluefin desktop defaults. If a setting is not a one-off runtime tweak and it should ship as part of the image, put it in the override file first. Do not invent a new file for a single setting when an existing override already exists.

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

## Default rule for future agents

- For image-default desktop settings: edit `system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override`
- For settings that must be immutable by users: edit both the override and `system_files/bluefin/etc/dconf/db/distro.d/locks/01-bluefin-locked-settings`
- For first-boot user-session behavior: use the existing hooks in `system_files/shared/usr/share/ublue-os/user-setup.hooks.d/` rather than adding new config files ad hoc
- Do not create a new schema override file for a single setting when the existing Bluefin override already exists

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

## dconf profile lookup order and CI test interference

The dconf profile shipped by bluefin images (`/etc/dconf/profile/user`) is:

```
user-db:user
system-db:local
system-db:site
system-db:distro
```

`local` has **higher priority than `distro`**. The testsuite's `e2e.yml` writes `/etc/dconf/db/local.d/00-ci-testing` before every VM boot:

```ini
[org/gnome/shell]
allow-extension-installation=true
enabled-extensions=['unsafe-mode@bluefin-test']
```

This means any `gsettings get org.gnome.shell enabled-extensions` call in a test returns only `['unsafe-mode@bluefin-test']`, not the distribution's default from the gschema override. The CI override wins regardless of what is in `distro.d/` or the compiled schema.

### Testing the distribution default vs the effective value

| Goal | Command | Why |
|---|---|---|
| Check what a real user sees | `gsettings get org.gnome.shell enabled-extensions` | Returns user-db > local > distro > schema |
| Check what the distro ships as default | `python3 -c "import gi; gi.require_version('Gio','2.0'); from gi.repository import Gio; v = Gio.Settings.new('org.gnome.shell').get_default_value('enabled-extensions'); print(v.unpack() if v else [])"` | Reads compiled schema, bypasses ALL dconf databases |
| Check a locked key | `gsettings get <key>` | Locked keys cannot be overridden — always returns distro value |

**Use `get_default_value()` in E2E tests that validate the OS ships the correct schema default.** Use `gsettings get` only when testing the effective runtime value or locked keys.

### Where enabled-extensions lives

`enabled-extensions` for `org.gnome.shell` is set in `system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override` — this sets the schema DEFAULT. It is NOT in `distro.d/` and is not a locked key, so users can override it.

The CI's `local.d/00-ci-testing` write overrides it in every test VM. Tests must use `get_default_value()` to validate this config, not `gsettings get`.

## Relocatable Schemas and GNOME Extensions

GSettings overrides (`.gschema.override` files) **do not support relocatable schemas** (schemas with omitted fixed paths, such as those used by many GNOME extensions like `blur-my-shell`). 

If you try to write an override block for a relocatable schema in `.gschema.override`, it will fail to compile or be discarded at compile time.

### How to configure relocatable schema defaults

To configure system-wide defaults for relocatable schemas, place them in path-based **dconf distro.d keyfiles** under `system_files/bluefin/etc/dconf/db/distro.d/` (such as `05-bluefin-searchlight-extension`) using slash-separated paths:

```ini
[org/gnome/shell/extensions/blur-my-shell/popup]
blur=false
```
