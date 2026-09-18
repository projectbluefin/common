# OEM Hardware Hooks — Hook Patterns and Migration Guide

Part of [oem-hardware-hooks](../SKILL.md) — version-script safe/anti-patterns; migrating a hook from bluefin to common; kernel-aware modprobe fixes; colormgr subcommands.

---

## The version-script contract — safe and anti-patterns

### Canonical safe pattern (from `11-asus.sh`)

`version-script` writes a stamp file on first call. **The stamp is written before your hook
logic runs.** If anything after the stamp call exits 1, the hook is permanently burned — it
will never retry on future logins.

```bash
# Check ALL transient preconditions before calling version-script
BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
if [[ ! -x "${BREW_BIN}" ]]; then
    echo "hook: brew not found, will retry on next login"
    exit 0   # ← exit 0 to retry; version-script not yet called
fi

# Only stamp once all preconditions pass
version-script myfeature user 1 || exit 0
```

### Anti-pattern to avoid

```bash
version-script myfeature user 1 || exit 0  # stamp fires here

# These exit 1 paths permanently skip the hook with no recovery:
if [[ -z "$DEVICE_ID" ]]; then
    exit 1   # ← BAD: hook burned, never retries
fi
```

For transient failures (service not ready, file not yet present), use
`exit 0` — not `exit 1` — so the hook retries on the next login.

---

## Migrating a hook from bluefin to common

1. Copy the script verbatim to the corresponding hooks.d directory in common
2. Add `# shellcheck disable=SC1091` before the `source` line
3. Keep the same `version-script` version number (do not bump)
4. If the hook depends on icon SVGs, copy them to
   `system_files/shared/usr/share/icons/hicolor/scalable/actions/`
5. Open a PR in common
6. After common ships, file a follow-up issue in `projectbluefin/bluefin`
   (and `bluefin-lts` if applicable) to delete the originals

**Check bluefin-lts path structure** — it uses `system_files/usr/share/...`
(no `shared/` prefix), unlike bluefin's `system_files/shared/usr/share/...`.
Confirm the exact path before filing the cleanup issue.

---

## Kernel-aware modprobe fixes

Some hardware workarounds are kernel-specific. Always check `/etc/os-release` before applying or removing modprobe flags:

```bash
if grep -q "^ID=fedora" /etc/os-release 2>/dev/null; then
    # Fedora kernel — native support, remove obsolete flag
else
    # Non-Fedora kernel (e.g. bluefin-lts on CentOS/RHEL) — flag still needed
fi
```

**Example:** AMD Framework 13 audio jack (`/etc/modprobe.d/alsa.conf`):
- Fedora kernel: handles natively → remove the file if it exists
- CentOS/RHEL kernel (bluefin-lts): still requires `options snd-hda-intel index=1,0 model=auto,dell-headset-multi`

Without this check, a common hook that removes the file will break AMD Framework 13 audio on bluefin-lts.

---

## colormgr — preferred subcommands for ICC profile hooks

When writing user-session hooks that assign ICC profiles via `colormgr`:

```bash
# Find the built-in display device (first display device)
DEVICE_ID=$(colormgr get-devices-by-kind display 2>/dev/null \
    | awk '/Device ID:/ { print $NF; exit }')

# Find a profile by filename (more robust than parsing get-profiles)
PROFILE_ID=$(colormgr find-profile-by-filename "$ICC_PATH" 2>/dev/null \
    | awk '/Profile ID:/ { print $NF; exit }')

# Assign
colormgr device-add-profile "$DEVICE_ID" "$PROFILE_ID"
colormgr device-make-profile-default "$DEVICE_ID" "$PROFILE_ID"
```

**Why `get-devices-by-kind display`** instead of `get-devices | grep`: limits output to
display devices from the start; no false-positive matches on other device property lines.

**Why `find-profile-by-filename`** instead of `get-profiles | awk`: direct lookup by path;
immune to output format changes across colord versions.

**Note:** colord does NOT auto-assign ICC profiles from `/usr/share/color/icc/colord/`
via EDID matching unless the profile contains `EDID_model`/`EDID_md5` metadata tags.
DisplayCAL/ArgyllCMS-generated profiles typically lack these tags — a user-session hook
with `colormgr` is required for auto-assignment on these systems.
