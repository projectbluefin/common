# Service Mechanics — brew-lifecycle

Part of [brew-lifecycle](../SKILL.md) — how brew-preinstall.service works, state file format, the per-login flow, the long-time-user removal scenario, bonedigger-report integration, variant-specific Brewfiles, merging order, and path conventions.

---

## How brew-preinstall works

**Brew is not installed in the OCI image.** The Containerfile is Alpine-based
and only assembles `/out/` directories (wallpapers, completions, udev rules,
binaries). The image ships the Brewfiles and the `brew-preinstall.service`
systemd unit. The actual brew packages are installed at **first user login**.

### Service

`brew-preinstall.service` is a user-level oneshot pulled in by
`graphical-session.target`. It explicitly runs after that target and
`ublue-user-setup.service`, uses `background.slice`, and lowers its I/O weight.
Keep the explicit `After=graphical-session.target` ordering: systemd target
units automatically complement wanted units with `After=` unless the wanted
unit supplies the inverse ordering, so omitting it puts the Homebrew pass on the
critical path for GNOME's generated application units. See
[`systemd.target`](https://www.freedesktop.org/software/systemd/man/latest/systemd.target.html#Automatic%20Dependencies).

User managers cannot depend on the system manager's `network-online.target`.
The service starts after the graphical session and relies on its bounded
`Restart=on-failure` policy when connectivity is not ready. It is enabled
globally via `usr/lib/systemd/user-preset/01-brew-preinstall.preset`.
Downstream repos do **not** need `systemctl --global enable` calls. The service
only runs when brew is installed at `/home/linuxbrew/.linuxbrew/bin/brew`.

### State file

`~/.local/share/ublue-os/brew-preinstall-state.json`
```json
{
  "hash": "<sha256 of all Brewfiles combined>",
  "packages": ["formula1"],
  "casks": ["cask1"]
}
```

State files created before cask management have no `casks` key. They are read
as an empty cask list and require no migration. The `packages` and `casks`
arrays contain declarations Bluefin owns, not every declaration in the current
Brewfiles.

### On every login

1. Hash all `preinstall.d/*.Brewfile` files combined.
2. Compare to stored hash. **Identical → fast exit**, nothing touched.
3. **Different:** snapshot installed formulae and casks, then run
   `brew bundle --file=` on each Brewfile (idempotent). A declaration already
   installed in the snapshot remains user-owned unless it was already present
   in the previous managed state. A new declaration absent from the snapshot
   becomes managed after the successful bundle pass.
   Continue through independent Brewfiles, but exit before removals and state
   writes if any bundle fails.
4. Diff previous formula and cask sets (from state JSON) against the current
   declarations (from Brewfiles). Uninstall dropped entries only if
   `brew list --formula` or `brew list --cask` confirms they are installed.
5. If any uninstall fails, exit before the state write so the removal is
   retried on the next service run.
6. Write the new hash, formula list, and cask list atomically (tmp + mv).

**The service is content-addressed, not version-numbered.** Never bump a
counter to propagate a Brewfile change — just edit the file. The hash change
triggers re-run automatically.

**Safety rule:** the uninstall step only removes packages that were in the
*previous managed state file*. If a user independently ran `brew install inxi`
themselves before `inxi` appeared in a managed Brewfile, the pre-bundle
snapshot keeps it out of managed state and a later Brewfile removal will never
touch it.

### What happens to long-time users on a package removal

Example: user has been running Bluefin since before `inxi`/`nvtop` were removed.
Their state file lists them in `packages`. On next login after the OS update:

1. Hash changes (Brewfile content changed) → triggers
2. `brew bundle` runs new 11-package list (no-ops for already-installed)
3. Diff: `previous = [..., inxi, nvtop, ...]`, `current = [...]` → `removed = [inxi, nvtop]`
4. `brew list inxi` → installed → `brew uninstall inxi --ignore-dependencies`
5. `brew list nvtop` → installed → `brew uninstall nvtop --ignore-dependencies`
6. State file updated with the new hash and managed formula/cask lists

Result: packages are **silently removed on the next login**. No prompt.

---

## Adding and removing packages — the exact steps

### Add a variant-specific Brewfile

Downstream repos can ship their own Brewfiles by dropping `*.Brewfile` files
into the same `preinstall.d/` directory in `system_files/<variant>/`. All
`*.Brewfile` files in the directory are hashed, bundled, and tracked together.

### ChairLift lifecycle and config ownership

ChairLift is a managed cask installed for every user from
`system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile`.
Keep both lines load-bearing:

```ruby
tap "frostyard/tap", trusted: true
cask "frostyard/tap/chairlift"
```

Homebrew 6 requires `trusted: true` for the Frostyard tap, and the cask must
remain pinned upstream in `frostyard/tap`.

Bluefin owns the maintainer defaults at `/usr/share/chairlift/config.yml`
(`system_files/shared/usr/share/chairlift/config.yml` in this repo). Admins own
`/etc/chairlift/config.yml`; never overwrite that path from image content,
setup services, or brew lifecycle code.

ChairLift treats unknown config keys as schema errors and disables the whole
application. `tests/check-chairlift-config` fetches the page, group, and field
schema from the ChairLift release the cask pins — one constant,
`CHAIRLIFT_SCHEMA_REF`, builds every upstream URL — and fails closed when
Bluefin's config drifts. Validating against upstream `main` instead would
false-green on a key the shipped binary rejects, which is the exact outcome
the gate exists to prevent. It needs network, so it is **not** part of
`just check`; `.github/workflows/validate-chairlift-config.yaml` owns it with a
path filter and a weekly cron. `test_just_check_stays_hermetic` enforces that
by walking the whole `check` recipe closure — the recipe body and every recipe
it depends on, not just the header line — so wiring the validator anywhere
under `check` fails the unit tests. Run the validator whenever the cask,
config, or upstream schema assumptions change.

Bootc staging is authenticated and stage-only. The image ships the fixed
`/usr/libexec/bootc-update-stage` helper and a PolicyKit action requiring admin
authentication. The helper runs plain `bootc upgrade` and nothing else:

| Flag | Why it is banned |
|---|---|
| `--apply`, `--soft-reboot` | Reboot the machine; when to reboot is the user's call |
| `--download-only` | Locks finalization, so the update does **not** apply on the next reboot, and re-locks a deployment uupd had already staged for shutdown |
| `--from-downloaded` | Only unlocks an existing download; never checks the registry |

Plain `bootc upgrade` fetches the update, queues it as a staged deployment, and
lets `ostree-finalize-staged` apply it at the user's next ordinary shutdown —
which is what ChairLift's UI reports after it re-reads `bootc status` and finds
a staged deployment. The helper must not suppress progress output (ChairLift
streams its merged stdout+stderr) or forward caller arguments into bootc.

### System-wide desktop integration

The cask installs the desktop entry and the three icons under the *installing*
user's `~/.local/share`. Homebrew uses a single shared prefix on Bluefin, so
for every subsequent user `brew bundle` sees the cask already installed, skips
it, and those users never get a launcher or an icon — managed casks with
user-scope artifacts are first-user-wins.

`common` closes that gap by shipping the same upstream artifacts image-side:

| Path | Source |
|---|---|
| `/usr/share/applications/org.frostyard.ChairLift.desktop` | upstream `data/org.frostyard.ChairLift.desktop`, `Exec=` rewritten to the absolute wrapper path |
| `/usr/share/icons/hicolor/scalable/apps/org.frostyard.ChairLift.svg` | upstream, verbatim |
| `/usr/share/icons/hicolor/scalable/apps/org.frostyard.ChairLift-flower.svg` | upstream, verbatim |
| `/usr/share/icons/hicolor/symbolic/apps/org.frostyard.ChairLift-symbolic.svg` | upstream, verbatim |

All four are vendored from ChairLift v0.10.1 (GPL-3.0, `frostyard/chairlift`)
and must be refreshed from the tag the cask pins whenever it is bumped. The
three icons are byte-identical to upstream, so the claim is checkable:

```bash
BASE=https://raw.githubusercontent.com/frostyard/chairlift/v0.10.1/data/icons/hicolor
cd system_files/shared/usr/share/icons/hicolor
for icon in scalable/apps/org.frostyard.ChairLift.svg \
            scalable/apps/org.frostyard.ChairLift-flower.svg \
            symbolic/apps/org.frostyard.ChairLift-symbolic.svg; do
  diff <(curl -fsSL "$BASE/$icon") "$icon" && echo "ok $icon"
done
```

To keep them that way they are excluded from `end-of-file-fixer` and
`check-added-large-files` in `.pre-commit-config.yaml`; upstream's two scalable
icons carry no trailing newline and exceed the 500 KiB default, and vendored
assets are not re-encoded. `Exec` points at
`/home/linuxbrew/.linuxbrew/bin/chairlift-wrapper`: the wrapper sets up the
Homebrew environment that a GDM-launched session PATH lacks, and `/var/home` is
the real path (`/home` is a symlink on bootc systems). The per-user copies the
cask still writes for the first user are harmless duplicates of the same entry.

---

## Confirming the service is working — bonedigger-report

`bonedigger-report` (`ujust report`) captures `systemctl list-units --state=failed`.
If `brew-preinstall.service` fails for a user, it appears in the **Failed Systemd
Units** section of their gist report. This is the primary signal available today.

**What is not captured today:**
- The brew-preinstall state file contents (`~/.local/share/ublue-os/brew-preinstall-state.json`)
- The brew-preinstall journal log (success path, hash, packages installed/removed)
- Whether the service ran successfully vs was skipped (brew not installed)

To add brew-preinstall health to bonedigger-report, append to the summary block
in `system_files/bluefin/usr/libexec/bonedigger-report`:
```bash
BREW_STATE="$(cat ~/.local/share/ublue-os/brew-preinstall-state.json 2>/dev/null || echo 'state file absent')"
BREW_SVC_STATUS="$(systemctl --user is-active brew-preinstall.service 2>/dev/null || echo unknown)"
BREW_SVC_LOG="$(journalctl --user -u brew-preinstall.service --no-pager -n 20 2>/dev/null || true)"
```
Then include these in the report markdown. This would let maintainers see at
a glance whether the service ran, which hash it applied, and what it installed.

---

## Merging order for the factory

When adding a package that spans multiple repos, merge in this order:

1. `projectbluefin/common` — add/remove from `preinstall.d/system-cli.Brewfile`
2. `projectbluefin/bluefin` — remove the RPM from `03-packages.sh`
3. `projectbluefin/bluefin-lts` — remove from `build_scripts/packages/base.toml`
4. `projectbluefin/dakota` — remove the `.bst` element from `elements/bluefin/`
   and its entry from `elements/bluefin/deps.bst`

The common PR must land first — downstream PRs depend on the service being
present in the image they consume.

---

## Path convention

Keep the real implementation in `/usr/libexec/brew-preinstall` and leave
`/usr/bin/brew-preinstall` as a thin compatibility wrapper. This matches
the bootc/FHS split: internal image helpers in `/usr/libexec`, user-facing
commands in `/usr/bin`, static Brewfiles in `/usr/share`.
