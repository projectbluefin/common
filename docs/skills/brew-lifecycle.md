---
name: brew-lifecycle
version: "1.1"
last_updated: "2026-07-22"
tags: [brew, homebrew, packages]
description: >-
  Manage OS-managed Homebrew packages. Use when adding/removing default brew
  packages, moving tools between RPM and brew, or auditing image-vs-brew
  placement.
metadata:
  type: procedure
  context7-sources:
    - /bootc-dev/bootc
    - /bootc-dev/bootc
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
- Debugging a failed or skipped `brew-preinstall.service`
- Deciding whether a new tool belongs on the image or in a Brewfile
- Auditing image diet (removing dead-weight packages from bluefin/lts/dakota)

## When NOT to Use

- Installing system-level packages (udev rules, kernel modules, daemons, firmware): those stay on the image as RPMs regardless
- `rpm-ostree install` is never the answer — see the rule below
- Adding user-installed (opt-in) packages: those go in the opt-in Brewfiles (`cli.Brewfile`, `cncf.Brewfile`, etc.), not `preinstall.d/`

---

## Current default package set (preinstall.d)

`system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/system-cli.Brewfile`
is the only file that auto-installs packages for every user on every variant.
As of 2026-06, it contains 11 packages:

| Package | Purpose | Deps |
|---|---|---|
| `fzf` | Fuzzy finder | static |
| `glow` | Markdown renderer | static |
| `htop` | Process viewer | `ncurses` |
| `rclone` | Cloud storage sync | static |
| `restic` | Backup tool | static |
| `smartmontools` | Drive SMART monitor | static |
| `squashfs` | Squashfs tools | `lz4, lzo, xz, zstd` |
| `starship` | Shell prompt | static |
| `tcpdump` | Packet analyzer | `libpcap, openssl@4` |
| `tmux` | Terminal multiplexer | `libevent, ncurses, utf8proc` |
| `ykman` | YubiKey management | `cryptography, python@3.14` |

**Removed:** `inxi` (system info, redundant with `fastfetch` on the image) and
`nvtop` (GPU monitor, hardware-specific — not everyone has a GPU).

### What belongs in preinstall.d

`preinstall.d/` is for packages every user gets automatically, managed
entirely by the OS. The contract is unambiguous:

**Add a line → every user gets it on next login after update.**
**Remove a line → every user who got it through the managed set gets it
uninstalled on next login after update.**

**Belongs here:**
- Universal CLI tools with no hardware prerequisite
- Tools that should be present before the user does anything
- Things with broad utility regardless of workflow (backups, prompt, terminal)
- Static binaries preferred — zero transitive deps is ideal

**Does not belong here:**
- Hardware-specific tools (`nvtop` — not everyone has a GPU)
- Tool-specific workflows (`ykman` — not everyone has a YubiKey, but it stays
  for now as a low-cost dep carrier; revisit if `python@3.14` becomes a problem)
- Anything that is naturally opt-in (`k8s-tools`, `cncf`, `ide`, etc.) — those
  go in the other Brewfiles and are only installed when the user runs `ujust bbrew`
- Packages already on the image (`fastfetch`, `gum`, `just`, `gcc`) — no need
  to duplicate them in brew

---

## How brew-preinstall works

**Brew is not installed in the OCI image.** The Containerfile is Alpine-based
and only assembles `/out/` directories (wallpapers, completions, udev rules,
binaries). The image ships the Brewfiles and the `brew-preinstall.service`
systemd unit. The actual brew packages are installed at **first user login**.

### Service

`brew-preinstall.service` is a user-level oneshot that fires after
`network-online.target` and `ublue-user-setup.service`. It is enabled globally
via `usr/lib/systemd/user-preset/01-brew-preinstall.preset`. Downstream repos
do **not** need `systemctl --global enable` calls. The service only runs when
brew is installed at `/var/home/linuxbrew/.linuxbrew/bin/brew`.

### State file

`~/.local/share/ublue-os/brew-preinstall-state.json`
```json
{ "hash": "<sha256 of all Brewfiles combined>", "packages": ["pkg1", ...], "casks": ["cask1", ...] }
```

Older state files without a `casks` key are read as an empty cask list;
no migration is needed.

### On every login

1. Hash all `preinstall.d/*.Brewfile` files combined.
2. Compare to stored hash. **Identical → fast exit**, nothing touched.
3. **Different:** run `brew bundle --file=` on each Brewfile (idempotent).
4. Diff previous `packages`/`casks` (from state JSON) against the current
   `brew "..."`/`cask "..."` lines (from Brewfiles). Uninstall entries that
   were in the old set but not the new one — **only if `brew list` confirms
   they are installed**. Casks are removed with `brew uninstall --cask`.
5. Write new hash + package and cask lists to state file atomically (tmp + mv).

**The service is content-addressed, not version-numbered.** Never bump a
counter to propagate a Brewfile change — just edit the file. The hash change
triggers re-run automatically.

**Safety rule:** the uninstall step only removes packages that were in the
*previous managed state file*. If a user independently ran `brew install inxi`
themselves, it is not in their state file's managed list and will never be
touched.

### What happens to long-time users on a package removal

Example: user has been running Bluefin since before `inxi`/`nvtop` were removed.
Their state file lists them in `packages`. On next login after the OS update:

1. Hash changes (Brewfile content changed) → triggers
2. `brew bundle` runs new 11-package list (no-ops for already-installed)
3. Diff: `previous = [..., inxi, nvtop, ...]`, `current = [...]` → `removed = [inxi, nvtop]`
4. `brew list inxi` → installed → `brew uninstall inxi --ignore-dependencies`
5. `brew list nvtop` → installed → `brew uninstall nvtop --ignore-dependencies`
6. State file updated with new hash + 11-package list

Result: packages are **silently removed on the next login**. No prompt.

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
3. On next login after the OS update, users who got it through the managed set
   get it uninstalled. Users who installed it themselves are unaffected.

### Add a tap + package from a non-core tap

Homebrew 6.0 syntax — `trusted: true` is required:
```ruby
tap "projectbluefin/bluefinctl", trusted: true
brew "bluefinctl"
```
Without `trusted: true` the tap is blocked and the formula is silently
unavailable. See [Homebrew 6.0 tap trust](#homebrew-60-tap-trust-required-as-of-2026-06-11).

### Add a cask (GUI app)

`cask "<name>"` lines get the same managed lifecycle as `brew "<name>"`
lines: installed by `brew bundle`, tracked in the state file under
`casks`, and uninstalled with `brew uninstall --cask` when the line is
removed. Verify with `bats tests/test_brew_preinstall.bats`.

### Add a variant-specific Brewfile

Downstream repos can ship their own Brewfiles by dropping `*.Brewfile` files
into the same `preinstall.d/` directory in `system_files/<variant>/`. All
`*.Brewfile` files in the directory are hashed, bundled, and tracked together.

---

## Homebrew 6.0 tap trust (required as of 2026-06-11)

Homebrew 6.0.0 blocks untrusted taps — formulae/casks from them are silently
unavailable unless the tap is explicitly trusted. This affects `ublue-os/tap`
and `ublue-os/experimental-tap` which ship VS Code, VSCodium, JetBrains,
Antigravity, Zed, Cursor, framework_tool, asusctl-linux.

**In just recipes** that call `brew tap` before cask installs:
```diff
- brew tap ublue-os/tap 2>/dev/null || true
+ brew tap --trust ublue-os/tap
```
The `|| true` silencer must be removed — tap failures should surface.

**In Brewfiles** that declare taps (Homebrew 6.0 Brewfile-native syntax):
```ruby
tap "ublue-os/tap", trusted: true
tap "ublue-os/experimental-tap", trusted: true
```

**Do not use `HOMEBREW_TRUSTED_TAPS` env var** — this was a Homebrew 4.x
mechanism. The correct 6.0 approach is `--trust` at tap-time and
`trusted: true` in Brewfiles.

### Known trust issues in the codebase (as of 2026-06)

| File | Current code | Status |
|---|---|---|
| `system.just` dx recipe | `brew tap --trust ublue-os/tap` | ✅ correct |
| `system.just` dx recipe | `brew tap --trust ublue-os/experimental-tap` | ✅ correct |
| `apps.just` install-jetbrains-toolbox | `brew tap ublue-os/homebrew-tap` | ❌ wrong tap name + no `--trust` |
| `apps.just` bbrew recipe | `brew install Valkyrie00/homebrew-bbrew/bbrew` | ❌ 3rd-party tap, no trust |

Ref: https://brew.sh/2026/06/11/homebrew-6.0.0/

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

## Opt-in Brewfiles (ujust bbrew)

These live in `system_files/shared/usr/share/ublue-os/homebrew/` (not in
`preinstall.d/`) and are only installed when the user explicitly runs
`ujust bbrew` and picks from the menu:

- `ai-tools.Brewfile`
- `artwork.Brewfile`
- `cli.Brewfile`
- `cncf.Brewfile`
- `experimental-ide.Brewfile`
- `fonts.Brewfile`
- `ide.Brewfile`
- `k8s-tools.Brewfile`
- `swift.Brewfile`

Bluefin-specific (in `system_files/bluefin/`):
- `full-desktop.Brewfile` — GNOME Circle + community flatpaks

These are validated by the `validate-brewfiles.yaml` CI workflow on every PR
that touches `system_files/shared/usr/share/ublue-os/homebrew/**`.

---

## Rule: no rpm-ostree layering — ever

`rpm-ostree install` (layering) is **not supported in Bluefin under any circumstances**
and must never be suggested as a workaround for missing packages.

**Why it does not work:**
- bootc's atomic upgrade model tracks a single OCI image digest. A layered commit
  is a divergence from that digest that the factory cannot reason about, test, or roll back cleanly.
- Layering breaks zstd:chunked delta pulls — the rechunker produces layer-level
  deltas against the published image; a locally layered image has no matching
  published chunks and must pull the full image on the next upgrade.
- PAM/NSS/system-daemon packages installed via `rpm-ostree install` on a running
  system interact with the live OS in ways that differ from the build-time
  installation path, producing unreproducible system state.

**If a use case requires a package with system integration:**
- Bake it into the image via `FEDORA_PACKAGES` in `build_files/base/03-packages.sh` — or
- Accept that the use case is not supported on stock Bluefin and direct the user
  to a downstream custom image.

Do not suggest `rpm-ostree install` as a solution in issues, docs, or ujust recipes.

---

## Rule: what can move to brew

Only move a package if it is a self-contained CLI tool with **none** of:
- systemd services or timers
- udev rules
- kernel modules
- D-Bus system services
- FUSE / filesystem drivers
- firmware
- PAM modules

Anything with those kinds of dependencies stays on the image as an RPM.

**Must stay on image regardless (required before brew is available):**
- `gum`, `just`, `zenity` — used by ujust scripts
- `gcc`, `gcc-c++`, `make`, `git` — required by brew's build toolchain
- `bootc`, `uupd` — OS update stack
- `fastfetch` — called by ublue-motd before brew runs on first login

---

## Starship shell initialization

Starship is installed via `preinstall.d/system-cli.Brewfile` (not baked
into the image). Each shell initializes it with a silent fallback:

**bash** — `etc/profile.d/90-bluefin-starship.sh` (in `projectbluefin/bluefin`):
```sh
if command -v starship >/dev/null 2>&1; then
    _starship_bin="starship"
elif [ -x "/var/home/linuxbrew/.linuxbrew/bin/starship" ]; then
    _starship_bin="/var/home/linuxbrew/.linuxbrew/bin/starship"
else
    return 0  # silent fallback to default prompt
fi
eval "$("$_starship_bin" init bash)"
```
Why the explicit brew path: `profile.d` scripts run before `brew shellenv`
is sourced, so `command -v starship` always misses the brew-installed binary
unless the path is checked directly.

**zsh** — `etc/zsh/zshrc` (in `projectbluefin/common`):
`brew shellenv` runs before the `if type starship` check, so brew's bin
is in PATH by the time the check runs. No special handling needed.

**fish** — `usr/share/fish/vendor_conf.d/starship.fish` (in `projectbluefin/common`):
```fish
if command -q starship
    starship init fish | source
end
```
Falls back to `vendor_functions.d/fish_prompt.fish` when starship is absent.

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

---

## Red Flags

- Suggesting `rpm-ostree install` for any missing tool — this is never correct on Bluefin
- Adding a package to `preinstall.d/` that has a udev rule, kernel module, D-Bus system service, FUSE driver, firmware, or PAM dependency — it must stay as an RPM
- Adding a tap without `trusted: true` / `--trust` (Homebrew 6.0 blocks untrusted taps silently)
- Bumping a version number or manual stamp to "trigger" a brew-preinstall re-run — the service is content-addressed; edit the Brewfile and the hash change triggers it automatically
- Editing `preinstall.d/` in a downstream repo (bluefin, bluefin-lts, dakota) for packages that should live in `common` — common ships to all variants
- Assuming `brew-preinstall.service` ran successfully because it's enabled — the service exits 0 silently if brew is not yet installed; check `journalctl --user -u brew-preinstall.service`

## Verification

After any change to `preinstall.d/` or `brew-preinstall`:

- [ ] Package obeys the "can move to brew" rule: self-contained CLI, no system-level deps
- [ ] If adding a tap: `trusted: true` in the Brewfile line (Homebrew 6.0)
- [ ] `pre-commit run --all-files` passes (Brewfile format, YAML/TOML hygiene)
- [ ] `just test` passes (bats tests in `tests/test_brew_preinstall.bats`)
- [ ] If removing a package: confirmed it was in the previous managed state — it will be auto-uninstalled for existing users on next login
- [ ] Merging order followed if the change spans repos: common → bluefin → bluefin-lts → dakota

## Brewfile scope: shared/ vs bluefin/ for all-variant packages

**Rule:** Any package that should install on ALL variants (bluefin, bluefin-lts, dakota) must live in `system_files/shared/preinstall.d/`, not `system_files/bluefin/preinstall.d/`.

`system_files/bluefin/` is included by bluefin and bluefin-lts. Dakota also includes it via its `common.bst` element. However, the semantic intent of `bluefin/` is bluefin-family only. When a package is placed there with a comment like "bluefin + bluefin-lts only", it creates ambiguity about whether Dakota gets it.

**Resolution:** `shared/preinstall.d/` is the unambiguous home for any package that is factory-wide. `bluefin/preinstall.d/` should only contain packages that are intentionally absent from Dakota.

**Concrete example:** `bluefinctl.Brewfile` was in `bluefin/preinstall.d/` — Dakota appeared to get it incidentally but the intent was ambiguous. Moving it to `shared/preinstall.d/` made the intent explicit and confirmed coverage for all variants (common PR 750, 2026-06-21).
