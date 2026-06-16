---
name: brew-lifecycle
description: "Manage OS-managed Homebrew packages via brew-preinstall, preinstall.d, tap trust, and image-vs-brew placement rules. Use when adding/removing default brew packages or changing brew-preinstall."
metadata:
  context7-sources:
    - /bootc-dev/bootc
---

# brew-lifecycle — Homebrew Package Lifecycle for Bluefin

How to add, remove, and manage system-default Homebrew packages across
the Bluefin factory. Covers the brew-preinstall service, the preinstall.d
pattern, and the rules for what can and cannot move to brew.

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

Ref: https://brew.sh/2026/06/11/homebrew-6.0.0/

---

## The preinstall.d pattern

`brew-preinstall.service` is a user-level oneshot systemd service that
runs at first login after the network is up. It installs all Brewfiles
found in `/usr/share/ublue-os/homebrew/preinstall.d/` and tracks state
in `~/.local/share/ublue-os/brew-preinstall-state.json`.

**Path convention:** keep the real implementation in
`/usr/libexec/brew-preinstall` and leave `/usr/bin/brew-preinstall` as a
thin compatibility wrapper for systemd units, tests, or user entrypoints.
This matches the bootc/FHS split: internal image helpers in `/usr/libexec`,
user-facing commands in `/usr/bin`, static Brewfiles in `/usr/share`.

### Adding a package to the default set

1. Add a `brew "<name>"` line to
   `system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/system-cli.Brewfile`
   in `projectbluefin/common`.
2. Open a PR. No version bumping, no manual trigger — the content-addressed
   hash check in `brew-preinstall` detects the change automatically.
3. On the next login after the OS update, every user gets the package installed.

### Removing a package from the default set

1. Remove the `brew "<name>"` line from the Brewfile.
2. Open a PR.
3. On next login, `brew-preinstall` diffs the previous managed package list
   against the current one and uninstalls packages that were dropped.
   Packages the user installed outside of the managed set are never touched.

### Adding a variant-specific Brewfile

Downstream repos (bluefin, bluefin-lts, dakota) can ship their own
Brewfiles by dropping `*.Brewfile` files into the same `preinstall.d/`
directory. All `*.Brewfile` files in the directory are installed and
tracked together.

---

## How the service works

**State file:** `~/.local/share/ublue-os/brew-preinstall-state.json`
```json
{ "hash": "<sha256 of all Brewfiles combined>", "packages": ["pkg1", ...] }
```

**On every login:**
1. Hash all `preinstall.d/*.Brewfile` files combined.
2. Compare to stored hash. If identical → fast exit, no brew invoked.
3. If different: run `brew bundle --file=` on each Brewfile (idempotent).
4. Diff previous managed package list against current. Uninstall removed packages.
5. Write new hash + package list to state file.

**Key design property:** the service is content-addressed, not version-numbered.
Never bump a version counter to propagate a Brewfile change — just edit the
Brewfile. The hash change triggers the re-run automatically.

**State write is atomic:** the script writes to `${STATE_FILE}.tmp` then
`mv -f` renames it into place. This ensures the state file is never
partially written if the process is killed mid-run. Do not revert to a
direct `> "${STATE_FILE}"` write — corrupt state causes a full re-run on
next login (slow but safe), and that is the only failure mode worth avoiding
without sacrificing simplicity.

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

**If a use case requires a package with system integration (PAM modules,
NSS modules, system daemons, udev rules):**
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

## Enabled by default

`brew-preinstall.service` is enabled globally via
`usr/lib/systemd/user-preset/01-brew-preinstall.preset` in common.
Downstream repos do **not** need `systemctl --global enable` calls.
The service only runs when brew is installed at
`/var/home/linuxbrew/.linuxbrew/bin/brew`.
