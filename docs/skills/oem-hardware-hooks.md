---
name: common-oem-hardware-hooks
version: "1.0"
last_updated: 2026-06-23
tags: [hardware, oem, first-boot, hooks, shellcheck]
description: >-
  OEM hardware first-boot setup hooks in projectbluefin/common. Use when adding hardware-specific
  setup, understanding hook directories and versioning contract, or applying shellcheck requirements.
metadata:
  type: runbook
---

# oem-hardware-hooks — OEM Hardware First-Boot Setup in common

How to add, move, or maintain hardware-specific first-boot setup hooks
in `projectbluefin/common`. Covers the hook directories, the versioning
contract, shellcheck requirements, and what belongs here vs upstream.

---

## Hook directories

Two directories are scanned automatically at first boot — no registration needed:

| Directory | Runner | Runs as |
|---|---|---|
| `system_files/shared/usr/share/ublue-os/system-setup.hooks.d/` | `ublue-system-setup` (systemd system service) | root |
| `system_files/shared/usr/share/ublue-os/user-setup.hooks.d/` | `ublue-user-setup` (systemd user service) | current user |

The runners glob `*` in order — name scripts with a numeric prefix
(`10-`, `20-`) to control execution order.

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

**Critical when migrating a hook from a downstream repo to common:**
use the **same** version number that already exists in the downstream hook.
If you bump it, the hook re-runs on every existing bluefin system on next boot.
If you keep it the same, existing systems correctly skip it (already ran).

### version-script must fire AFTER all preconditions pass

`version-script` writes a stamp file on first call. **The stamp is written
before your hook logic runs.** If anything after the stamp call exits 1, the
hook is permanently burned — it will never retry on future logins.

**Canonical safe pattern** (from `11-asus.sh`):

```bash
# Check ALL transient preconditions before calling version-script
BREW_BIN="/var/home/linuxbrew/.linuxbrew/bin/brew"
if [[ ! -x "${BREW_BIN}" ]]; then
    echo "hook: brew not found, will retry on next login"
    exit 0   # ← exit 0 to retry; version-script not yet called
fi

# Only stamp once all preconditions pass
version-script myfeature user 1 || exit 0
```

**Anti-pattern to avoid:**

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

## Shellcheck requirement

CI runs `shellcheck -e SC2207` on all `*.sh` files in `system_files/`.
The `source /usr/lib/ublue/setup-services/libsetup.sh` line triggers SC1091
(can't follow a path not present at lint time). Suppress it inline:

```bash
# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh
```

This is the established pattern — see `20-dynamic-wallpaper.sh`.

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

## Hardware currently in common

| Hook | Type | What it does |
|---|---|---|
| `system-setup.hooks.d/10-framework.sh` | system | Intel Framework keyboard karg; Framework 13 Ryzen 7040 suspend fix; AMD 3.5mm jack (kernel-aware) |
| `system-setup.hooks.d/11-asus.sh` | system | Enables asusd.service + asus-shutdown.service once asusctl is installed |
| `user-setup.hooks.d/10-theming.sh` | user | Framework scroll/font tweaks; Thelio Astra Ampere logo (non-brew vendors) |
| `user-setup.hooks.d/20-oem-brew.sh` | user | Generic OEM brew install + logo set (data-driven, see below) |
| `user-setup.hooks.d/12-framework-color.sh` | user | Assigns factory ICC color profiles to Framework 13/16 displays via colormgr |

## OEM brew hook — data-driven pattern

`20-oem-brew.sh` is a single generic hook. It detects the vendor, looks up
`/usr/share/ublue-os/oem/<Vendor>/`, installs packages, and sets the logo.
The logo in the top-left menu reflects that HWE brew packages are installed
and active — a plain `u` means stock, a vendor logo means the OEM stack is running.

### Adding a new OEM

1. Add a `case` arm in `20-oem-brew.sh` mapping the DMI vendor string → canonical name:
   ```bash
   *:LENOVO*) VENDOR="Lenovo" ;;
   ```
   (`CHASSIS_VENDOR:SYS_VENDOR` — use whichever field is reliable for that hardware.)

2. Create the data directory:
   ```
   system_files/shared/usr/share/ublue-os/oem/<Vendor>/
     packages.Brewfile   # tap + cask declarations (trusted: true required)
     logo                # icon name, e.g. "lenovo-logo-symbolic"
   ```

3. Add the vendor logo SVG to:
   `system_files/shared/usr/share/icons/hicolor/scalable/actions/<name>-symbolic.svg`

4. If the OEM also needs user-session config files (for example a WirePlumber
   snippet), place them in the same `oem/<Vendor>/` directory and have
   `20-oem-brew.sh` install them into the user's home directory.

No new hook file is needed. Bump the hook version only when existing machines
must re-run the hook to pick up a new payload.

### OEM directories

| Vendor | Packages | Logo |
|---|---|---|
| `Framework` | `framework_tool`, `framework-wallpapers` | `framework-logo-symbolic` |
| `ASUS` | `asusctl-linux`, `rog-control-center-linux` | `asus-rog-symbolic` |

### Version stamp

The stamp slug is `oem-<Vendor> user 2`. This is intentionally separate from
the old `asus user 1` stamp — existing ASUS machines that already ran the old
`11-asus.sh` will pick up the new generic hook and get the logo set on next login.
The brew installs are idempotent (already-installed casks are skipped by brew).

**WirePlumber rules for Framework Desktop (AMD Ryzen AI Max 300):**
ship the snippet as OEM data in
`system_files/shared/usr/share/ublue-os/oem/Framework/51-framework-desktop.conf`
and let `20-oem-brew.sh` install it to
`~/.config/wireplumber/wireplumber.conf.d/51-framework-desktop.conf`
on Framework Desktop machines only (`product_name == "Framework Desktop"`).

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

## WirePlumber rules — use wireplumber.conf.d/, not hardware-profiles/

Bazzite ships WirePlumber rules in a `hardware-profiles/<product-name>/wireplumber.conf.d/`
subdirectory structure. **This is a bazzite-specific extension — it does NOT work in stock
Fedora/bluefin WirePlumber.**

Bazzite swaps wireplumber from their own COPR (`ublue-os/bazzite`) and enables
`wireplumber-sysconf.service` in deck builds to process those directories. Stock
WirePlumber 0.5.x (what bluefin ships) has no `hardware-profiles/` loader.

**For common:** do not drop OEM-specific WirePlumber snippets into
`system_files/shared/usr/share/wireplumber/wireplumber.conf.d/` — that ships
globally to every machine. If the rule only applies to one OEM family, store it in
that vendor's `oem/<Vendor>/` directory and have the OEM user hook copy it into the
user's WirePlumber fragment directory:

```bash
install -d "${HOME}/.config/wireplumber/wireplumber.conf.d"
install -m 0644 "${OEM_DIR}/${VENDOR}/51-framework-desktop.conf" \
  "${HOME}/.config/wireplumber/wireplumber.conf.d/51-framework-desktop.conf"
```

WirePlumber's documented user fragment path is
`~/.config/wireplumber/wireplumber.conf.d/`. The `node.name` match (PCI address or
pattern) still scopes the rule to the target hardware — no hardware-profiles
directory structure needed:

```conf
monitor.alsa.rules = [
  {
    matches = [{ node.name = "~alsa_output.pci-0000_c3_00.1.*" }]
    actions = {
      update-props = {
        priority.driver = 1100
        priority.session = 1100
      }
    }
  }
]
```

Use `~` prefix for regex matching to avoid PCI minor-revision fragility.

If you add a new OEM payload to an existing versioned setup hook and want current
users to receive it, bump that hook's `version-script` version. Otherwise existing
machines skip the new logic forever because the old stamp already exists.

If an OEM payload only applies to one model within a vendor family, gate the copy
on DMI `product_name` as well as vendor. `Framework` alone is too broad — it would
also match Framework laptops.

If the OEM payload is a user-level config file that should survive failed setup
retries, run its copy step **after** the versioned work block and make it
idempotent (`install -d` + `install`). That way existing stamped systems still get
the file and repeated logins safely refresh it.

## Sources

- WirePlumber config fragments and user override path: Context7 `/websites/pipewire_pages_freedesktop_wireplumber`

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

---

## Known gaps (tracking issues)

- `20-framework.sh` in `projectbluefin/bluefin` is superseded by `20-oem-brew.sh` in common — file a cleanup issue in bluefin to delete it after common ships.
- `apps.just` ASUS recipe still calls `brew install --cask` directly without `--trust`; update to use Brewfile or `--trust` flag.
