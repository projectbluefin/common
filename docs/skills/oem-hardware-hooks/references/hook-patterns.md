# OEM Hardware Hooks — Hook Patterns and Migration Guide

Part of [oem-hardware-hooks](../SKILL.md) — version-script safe/anti-patterns; migrating a hook from bluefin to common; kernel-aware modprobe fixes; colormgr subcommands.

---

## The version-script contract — safe and anti-patterns

### Canonical safe pattern (from `11-asus.sh` and `20-oem-brew.sh`)

`version-script-check` is a **gate that records no version** — it tells you whether the hook
has already run at this version. `version-script-commit`
**writes the stamp**, and it is only reached if the hook body got there
without failing. Split the two so a failing body never records and retries
next boot (this is projectbluefin/common#1137). The legacy `version-script`
records before the body runs; it is kept only for existing downstream callers.

```bash
set -euo pipefail
source /usr/lib/ublue/setup-services/libsetup.sh

# Resolve the interpreter up front so the `[[ -x ]]` check below is safe under
# `set -u` — the example used to reference ${BREW_BIN} without assigning it.
BREW_BIN="$(command -v brew 2>/dev/null || true)"

# Check ALL transient preconditions first.
if [[ ! -x "${BREW_BIN}" ]]; then
    echo "hook: brew not found, will retry on next login"
    exit 0   # ← exit 0 to retry; nothing committed yet
fi

# Read-only gate at the top: `|| exit 0` exits if already at this version.
version-script-check myfeature user 1 || exit 0

# ... your setup work ...

# Record success ONLY at the end, after the body ran. With `set -e` a failing
# step aborts here, so the version is never committed and the hook retries.
version-script-commit myfeature user 1
```

### Anti-pattern to avoid

```bash
# Legacy gate: version-script records the stamp BEFORE the body runs.
version-script myfeature user 1 || exit 0
# ... work that exits 1 ... — the stamp is already written, so the hook is
# permanently skipped on every later run.
```

Use `version-script-check` + `version-script-commit` instead. A body that
fails *before* `version-script-commit` must not record: keep transient
failures on `exit 0`, and add `set -e` so hard failures abort before the
commit.

---

## Migrating a hook from bluefin to common

1. Copy the script verbatim to the corresponding hooks.d directory in common
2. Add `# shellcheck disable=SC1091` before the `source` line
3. Keep the same version number (do not bump); if the hook still uses the
   legacy `version-script`, switch it to `version-script-check` plus a
   `version-script-commit` at the end of the body
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
