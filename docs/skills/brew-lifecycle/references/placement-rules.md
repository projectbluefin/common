# Placement Rules — brew-lifecycle

Part of [brew-lifecycle](../SKILL.md) — the no-rpm-ostree rule, what can move to brew, Homebrew 6.0 tap trust requirements, and Starship shell initialization details.

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

## Homebrew 6.0 tap trust (required as of 2026-06-11)

Homebrew 6.0.0 blocks untrusted taps — formulae/casks from them are silently
unavailable unless the tap is explicitly trusted. This affects `ublue-os/tap`
and `ublue-os/experimental-tap` which ship VS Code, VSCodium, JetBrains,
Antigravity, Zed, Cursor, framework_tool, asusctl-linux.

**In just recipes** that call `brew tap` before cask installs, trust is a
**separate command** — `--trust` is not a valid `brew tap` flag and Homebrew
6.0 exits non-zero on it:
```diff
- brew tap --trust ublue-os/tap
+ brew tap ublue-os/tap 2>/dev/null || true
+ brew trust ublue-os/tap 2>/dev/null || true
```
`brew tap` is idempotent and errors when the tap already exists, so keep the
`2>/dev/null || true` guard — especially inside `set -euo pipefail` recipes.

**In Brewfiles** that declare taps (Homebrew 6.0 Brewfile-native syntax):
```ruby
tap "ublue-os/tap", trusted: true
tap "ublue-os/experimental-tap", trusted: true
```

**Do not use `HOMEBREW_TRUSTED_TAPS` env var** — this was a Homebrew 4.x
mechanism. The correct 6.0 approach is `brew trust <tap>` after `brew tap`,
and `trusted: true` in Brewfiles. See https://docs.brew.sh/Tap-Trust.

### Tap trust call sites

| File | Expected code |
|---|---|
| `system.just` dx recipe | `brew tap ublue-os/tap` + `brew trust ublue-os/tap` |
| `system.just` dx recipe | `brew tap ublue-os/experimental-tap` + `brew trust ublue-os/experimental-tap` |
| `apps.just` install-jetbrains-toolbox | `brew tap ublue-os/tap` + `brew trust ublue-os/tap` |
| `apps.just` install-asus | `brew tap ublue-os/tap` + `brew trust ublue-os/tap` |
| `bazaar-hook` `spawn_brew` | `brew tap ublue-os/tap` + `brew trust ublue-os/tap` |

Regression coverage lives in `tests/test_brew_tap_trust.bats`.

Ref: https://brew.sh/2026/06/11/homebrew-6.0.0/

---

## Linux cask checksum keys

Architecture-specific cask checksums are OS-specific. For Linux artifacts,
use Homebrew's Linux keys:

```ruby
sha256 arm64_linux:  "<arm64-sha256>",
       x86_64_linux: "<amd64-sha256>"
```

Do not use `arm:` / `intel:` for a Linux-only cask. Those keys select macOS
checksums, leaving `sha256` unset when Homebrew simulates Linux. `brew readall`
then reports `Missing Linux stanzas can leave Linux sha256 as nil`, and
`brew audit` reports that a checksum is required.

Source: Homebrew Cask DSL (`/homebrew/brew`).

---

## Starship shell initialization

Starship is installed via `preinstall.d/system-cli.Brewfile` (not baked
into the image). Each shell initializes it with a silent fallback:

**bash** — `etc/profile.d/90-bluefin-starship.sh` (in `projectbluefin/bluefin`):
```sh
if command -v starship >/dev/null 2>&1; then
    _starship_bin="starship"
elif [ -x "/home/linuxbrew/.linuxbrew/bin/starship" ]; then
    _starship_bin="/home/linuxbrew/.linuxbrew/bin/starship"
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
