---
name: oem-hardware-hooks
version: "1.1"
last_updated: "2026-09-13"
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

| Directory | Runner | Runs as |
|---|---|---|
| `system_files/shared/usr/share/ublue-os/system-setup.hooks.d/` | `ublue-system-setup` (systemd system service) | root |
| `system_files/shared/usr/share/ublue-os/user-setup.hooks.d/` | `ublue-user-setup` (systemd user service) | current user |

Name scripts with a numeric prefix (`10-`, `20-`) to control execution order.

A hook is the right tool for a **one-time first-boot action for the current
user**. For a desktop or GNOME *setting*, it is usually the wrong tool — use the
gschema override and lock files instead. That decision belongs to
[`dconf-consistency.md`](../dconf-consistency.md); do not restate its rules here.

The runners are thin wrappers over one dispatcher — see "Setup services" below.

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

### What `version-script` guarantees

`shared/usr/lib/ublue/setup-services/libsetup.sh` is the idempotency guard for
every first-boot setup script, not just OEM hooks. It is concurrent-safe
(`flock -x` on fd 200 against a `.lock` beside the state file, so user-setup and
privileged-setup starting together cannot both read before either writes),
corruption-safe (validates with `jq`; a corrupt `setup_versioning.json` resets
to `{}` with a warning rather than silently skipping setup), and leaves no temp
files (`trap 'rm -f "${tmp}"' EXIT` inside the subshell). State lives at
`~/.local/share/ublue/setup_versioning.json` — user-scoped, not global. Covered
by `tests/test_libsetup.bats`.

### Setup services — one dispatcher, three wrappers

`shared/usr/lib/ublue/setup-services/hookrunner.sh` is the single source of
truth for how the setup services discover and run hooks. `ublue-system-setup`,
`ublue-user-setup` and `ublue-privileged-setup` are thin wrappers that supply
only their `/etc/ublue-os/setup.json` key and default directory:

```bash
HOOKRUNNER="${HOOKRUNNER:-/usr/lib/ublue/setup-services/hookrunner.sh}"
source "${HOOKRUNNER}"
run_setup_hooks "user-hooks-directory" "/usr/share/ublue-os/user-setup.hooks.d"
```

| Wrapper | Config key | Default directory |
|---|---|---|
| `ublue-system-setup` | `system-hooks-directory` | `/usr/share/ublue-os/system-setup.hooks.d` |
| `ublue-user-setup` | `user-hooks-directory` | `/usr/share/ublue-os/user-setup.hooks.d` |
| `ublue-privileged-setup` | `privileged-hooks-directory` | `/usr/share/ublue-os/privileged-setup.hooks.d` |

`$HOOKRUNNER` is overridable so the wrappers can be exercised from a source
checkout, matching the `$LIBSETUP` convention the hooks use.

**Do not** reintroduce a private `get_config` or `for script in ...` loop in a
wrapper — `tests/test_setup_scripts.bats` fails the build if you do. The three
scripts were byte-identical copies once, which is how a single dispatch-loop
defect shipped three times over. Also covered by `tests/test_privileged_setup.bats`.

---

## Shellcheck requirement

Two CI jobs shellcheck `system_files/`, both driving off
`find system_files -name '*.sh'`, with **different** exclusion sets:

| Workflow | Invocation |
|---|---|
| `.github/workflows/validate.yml` | `shellcheck -e SC2207` |
| `.github/workflows/unit-tests.yml` | `shellcheck -e SC1091`, plus an explicit list of nine extensionless scripts |

A hook must pass **both**. Since neither excludes SC1091 everywhere, always
suppress it inline at the `source`:

```bash
# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh
```

Note that `-name '*.sh'` matches hooks (they all end in `.sh`) but misses every
extensionless executable in `usr/libexec/`. See
[`docs/TESTING.md`](../../TESTING.md#coverage-targets).

---

## What belongs in common vs downstream

A hook belongs in `common` if it is pure hardware detection (DMI vendor/product,
CPU vendor, BIOS version) with no Fedora/Bluefin-version dependency, and should
apply to every variant including bluefin-lts.

Leave it downstream if it depends on packages or services only that variant
ships, needs `brew install --cask` (tap trust must be configured first), or
touches dconf keys present in only one variant's GNOME extension set.

---

## Hooks currently in common

Four, and only four:

| Hook | Type | What it does | Tested by |
|---|---|---|---|
| `system-setup.hooks.d/10-framework.sh` | system | Intel Framework keyboard karg; Framework 13 Ryzen 7040 suspend fix; AMD 3.5mm jack (kernel-aware) | `tests/test_hardware_hooks.bats` |
| `system-setup.hooks.d/11-asus.sh` | system | Enables `asusd.service` + `asus-shutdown.service` once asusctl is installed | `tests/test_hardware_hooks.bats` |
| `user-setup.hooks.d/10-theming.sh` | user | Framework scroll/font tweaks; Thelio Astra Ampere logo (non-brew vendors) | `tests/test_theming_hook.bats` |
| `user-setup.hooks.d/20-oem-brew.sh` | user | Generic OEM brew install + logo set (data-driven) | `tests/test_oem_brew.bats` |

All four read their hardware facts through overrides (`LIBSETUP`, `SYSROOT`)
so the tests can point them at a fixture DMI tree. A new hook that reads
`/sys` directly is untestable — see [`docs/TESTING.md`](../../TESTING.md#hardware-gate-boundary).

`bluefin/usr/share/ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh` is in
the `bluefin` layer, not `shared`, and is not an OEM hook: it enables the
dynamic-wallpaper timer. Its logic lives in
`bluefin/usr/libexec/bluefin-dynamic-wallpaper` (`tests/test_dynamic_wallpaper.bats`).

---

## Red Flags

- Dropping OEM-specific WirePlumber snippets into `system_files/shared/usr/share/wireplumber/wireplumber.conf.d/` — that path ships globally, to every variant
- Assuming bazzite's `hardware-profiles/` loader works in stock bluefin WirePlumber

---

## Verification

- [ ] `shellcheck -e SC2207` **and** `shellcheck -e SC1091` pass on all modified `*.sh` files
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
