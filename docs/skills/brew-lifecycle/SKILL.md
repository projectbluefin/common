---
name: brew-lifecycle
version: "1.4"
last_updated: "2026-08-18"
id: brew-lifecycle
one_line_purpose: Manage OS-managed Homebrew packages and RPM/brew placement.
entry_point: docs/skills/brew-lifecycle/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [brew, homebrew, packages]
description: >-
  Manage OS-managed Homebrew packages. Use when adding/removing default brew
  packages, moving tools between RPM and brew, or auditing image-vs-brew
  placement.
metadata:
  type: procedure
  context7-sources:
    - /bootc-dev/bootc
    - /homebrew/brew
    - /systemd/systemd
---

# brew-lifecycle — Homebrew Package Lifecycle for Bluefin

How to add, remove, and manage system-default Homebrew packages across
the Bluefin factory. Covers the brew-preinstall service, the preinstall.d
pattern, and the rules for what can and cannot move to brew.

---

## When to Use

- Adding or removing a package from `preinstall.d/system-cli.Brewfile`
- Moving a self-contained CLI tool off the RPM image and into brew
- Adding or removing a tap (`trusted: true` requirements, Brewfile syntax)
- Pinning architecture-specific checksums for a Linux cask
- Debugging a failed or skipped `brew-preinstall.service`
- Deciding whether a new tool belongs on the image or in a Brewfile
- Auditing image diet (removing dead-weight packages from bluefin/lts/dakota)

## When NOT to Use

- Installing system-level packages (udev rules, kernel modules, daemons, firmware): those stay on the image as RPMs regardless
- `rpm-ostree install` is never the answer — see [placement-rules.md](references/placement-rules.md)
- Adding user-installed (opt-in) packages: those go in the opt-in Brewfiles (`cli.Brewfile`, `cncf.Brewfile`, etc.), not `preinstall.d/`

---

## Adding and removing packages — the exact steps

### Add a package
1. Add a `brew "<name>"` line to
   `system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/system-cli.Brewfile`
2. Open a PR. No version bumping, no manual trigger.
3. On next login after the OS update, every user gets the package installed.

### Remove a package
1. Remove the `brew "<name>"` line from the Brewfile.
2. Open a PR.
3. On next successful login sync after the OS update, packages recorded in
   the previous managed state get uninstalled. Packages outside that state
   are unaffected. State records the desired set, not who originally installed
   each package, so a manually installed package can later become managed.

Bluefinctl is no longer provisioned by common. Removing its dedicated Brewfile
uses this existing lifecycle to uninstall state-tracked copies; no separate
cleanup script is needed. Native `ujust` recipes must not delegate to `bctl`,
even if an untracked copy remains installed.

### Add or remove a cask

Use `cask "<name>"` in a managed Brewfile. The service installs casks through
the existing `brew bundle` pass, tracks them separately in the state file, and
uses `brew uninstall --cask` when a managed cask is removed.

The repository validator and lifecycle parser accept indentation and either
Ruby quote style:

```ruby
cask "chairlift"
cask 'chairlift'
```

Legacy state files without a `casks` key require no migration.

### ChairLift managed cask

ChairLift is a managed cask installed for every user through
`system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile`:

```ruby
tap "frostyard/tap", trusted: true
cask "chairlift"
```

The tap line requires `trusted: true`; Homebrew 6 blocks untrusted taps. The
cask must remain pinned upstream in `frostyard/tap` rather than being replaced
with a local mutable download in common.

Bluefin owns `/usr/share/chairlift/config.yml`, shipped from
`system_files/shared/usr/share/chairlift/config.yml`. `/etc/chairlift/config.yml`
is administrator-owned override state and must not be overwritten by image
content or lifecycle code.

ChairLift fails closed on schema drift: an unknown page, group, or field key in
`config.yml` disables the whole application. Keep policy that has no upstream
key in YAML comments, and verify with `python3 tests/check-chairlift-config`.

Bootc staging is authenticated and stage-only. ChairLift invokes the
PolicyKit-gated `/usr/libexec/bootc-update-stage` helper, which runs plain
`bootc upgrade`: that queues a staged deployment which `ostree-finalize-staged`
applies at the user's own next shutdown. The helper must not accept
caller-provided bootc arguments and must never pass `--apply`/`--soft-reboot`
(they reboot), `--download-only` (it locks finalization, so nothing applies on
reboot and an update uupd already staged gets re-locked), or
`--from-downloaded` (it never checks the registry).

Desktop integration ships from the image, not the cask. Homebrew has one
shared prefix, so the cask's `~/.local/share` desktop entry and icons only
ever reach the first user to run `brew bundle`. `common` ships the upstream
desktop file at `/usr/share/applications/org.frostyard.ChairLift.desktop`
(`Exec=/home/linuxbrew/.linuxbrew/bin/chairlift-wrapper`) and the three
upstream icons under `/usr/share/icons/hicolor/`, so every user gets a
launcher.

### Add a tap + package from a non-core tap

Homebrew 6.0 syntax — `trusted: true` is required:
```ruby
tap "frostyard/tap", trusted: true
cask "chairlift"
```
Without `trusted: true` the tap is blocked and the formula is silently
unavailable. See [placement-rules.md](references/placement-rules.md#homebrew-60-tap-trust-required-as-of-2026-06-11).

### Brewfile placement rule

Any package that installs on ALL variants must live in `system_files/shared/preinstall.d/`,
not `system_files/bluefin/preinstall.d/`. See [package-set.md](references/package-set.md#brewfile-scope-shared-vs-bluefin-for-all-variant-packages).

---

## Red Flags

- Suggesting `rpm-ostree install` for any missing tool — this is never correct on Bluefin
- Adding a package to `preinstall.d/` that has a udev rule, kernel module, D-Bus system service, FUSE driver, firmware, or PAM dependency — it must stay as an RPM
- Adding a tap without `trusted: true` in a Brewfile, or without a `brew trust` call after `brew tap` in a recipe (Homebrew 6.0 blocks untrusted taps silently)
- Passing `--trust` to `brew tap` — it is not a valid flag and Homebrew 6.0 exits non-zero; use `brew trust <tap>` as a separate command
- Using `arm:` / `intel:` checksum keys for a Linux cask — those keys are macOS-only and resolve to no checksum on Linux
- Adding unknown keys to `/usr/share/chairlift/config.yml` — ChairLift disables
  the whole application on unknown page, group, or field names
- Writing `/etc/chairlift/config.yml` from image content or setup code; that
  path is administrator-owned override state
- Bumping a version number or manual stamp to "trigger" a brew-preinstall re-run — the service is content-addressed; edit the Brewfile and the hash change triggers it automatically
- Writing lifecycle code that advances the state hash after a failed bundle or uninstall — failures must leave state unchanged so the next login retries
- Editing `preinstall.d/` in a downstream repo (bluefin, bluefin-lts, dakota) for packages that should live in `common` — common ships to all variants
- Assuming `brew-preinstall.service` ran successfully because it's enabled — the service exits 0 silently if brew is not yet installed; check `journalctl --user -u brew-preinstall.service`
- Removing `After=graphical-session.target` from `brew-preinstall.service` — target units automatically order themselves after wanted units unless the wanted unit explicitly supplies the inverse ordering, which would put this oneshot back on GNOME's application-launch critical path

## Verification

After any change to `preinstall.d/` or `brew-preinstall`:

- [ ] Package obeys the "can move to brew" rule: self-contained CLI, no system-level deps
- [ ] If adding a tap: `trusted: true` in the Brewfile line (Homebrew 6.0)
- [ ] Linux casks use `arm64_linux:` / `x86_64_linux:` checksum keys
- [ ] If adding a cask: it is recorded under `.casks` and removal uses `brew uninstall --cask`
- [ ] If touching ChairLift: `python3 tests/check-chairlift-config` passes (networked; not part of `just check`)
- [ ] If bumping the ChairLift cask: `CHAIRLIFT_SCHEMA_REF` in `tests/check-chairlift-config` and the vendored desktop file/icons move in the same change
- [ ] Bundle and uninstall failures leave the previous state hash intact for retry
- [ ] The systemd user unit remains ordered after `graphical-session.target`, in `background.slice`, and at reduced I/O weight
- [ ] User units do not reference the system manager's `network-online.target`; network failures use the service retry policy
- [ ] `pre-commit run --all-files` passes (Brewfile format, YAML/TOML hygiene)
- [ ] `just test` passes (bats tests in `tests/test_brew_preinstall.bats`)
- [ ] If removing a package: confirmed it was in the previous managed state — it will be auto-uninstalled for existing users on next login
- [ ] Merging order followed if the change spans repos: common → bluefin → bluefin-lts → dakota

## References

| File | Contents |
|---|---|
| [package-set.md](references/package-set.md) | Current 11-package default set, ChairLift managed cask, what belongs in preinstall.d, fzf/ujust bootstrap, opt-in Brewfiles, shared/ vs bluefin/ placement rule |
| [service-mechanics.md](references/service-mechanics.md) | How brew-preinstall.service works, state file format, login flow, ChairLift config ownership, long-time user removal scenario, bonedigger-report integration, merging order, path convention |
| [placement-rules.md](references/placement-rules.md) | No rpm-ostree rule, what can move to brew, Homebrew 6.0 tap trust details, Starship shell initialization |
