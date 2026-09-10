# Package Set — brew-lifecycle

Part of [brew-lifecycle](../SKILL.md) — current default package list, what belongs in preinstall.d, the fzf/ujust bootstrap, opt-in Brewfiles, and the shared/ vs bluefin/ placement rule.

---

## Current default package set (preinstall.d)

`system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/system-cli.Brewfile`
defines the default CLI set. Other Brewfiles in the same directory also
provision managed packages for every variant. The CLI set contains 11 packages:

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

### Managed casks

`system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile`
installs ChairLift for every user:

```ruby
tap "frostyard/tap", trusted: true
cask "chairlift"
```

This is OS-managed like the default formula set: add the cask and every user
gets it on next login after update; remove it and users whose state file shows
it as managed have it uninstalled. The `trusted: true` tap flag is required.
The cask must remain pinned upstream in `frostyard/tap`; do not vendor an
unpinned replacement cask into common.

The cask's desktop entry and icons land in the installing user's
`~/.local/share`, which — with Homebrew's single shared prefix — means only the
first user ever receives them. `common` therefore also ships the upstream
desktop file and icons system-wide; see
[service-mechanics.md](service-mechanics.md).

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

### `fzf` and `ujust --choose`

`fzf` is managed through `system-cli.Brewfile`, so it may be unavailable before
the first-login `brew-preinstall.service` completes. The `ujust` wrapper
bootstraps `fzf` on demand when `--choose` is requested, then reinitializes the
Homebrew environment before dispatching to `just`. Keep this bootstrap path
separate from ordinary `ujust` commands so missing Homebrew does not affect
non-interactive recipes.

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
- `fonts-dev.Brewfile`
- `ide.Brewfile`
- `k8s-tools.Brewfile`
- `swift.Brewfile`

Bluefin-specific (in `system_files/bluefin/`):
- `full-desktop.Brewfile` — GNOME Circle + community flatpaks

These are validated by the `validate-brewfiles.yaml` CI workflow on every PR
that touches `system_files/shared/usr/share/ublue-os/homebrew/**`.

---

## Brewfile scope: shared/ vs bluefin/ for all-variant packages

**Rule:** Any package that should install on ALL variants (bluefin, bluefin-lts, dakota) must live in `system_files/shared/preinstall.d/`, not `system_files/bluefin/preinstall.d/`.

`system_files/bluefin/` is included by bluefin and bluefin-lts. Dakota also includes it via its `common.bst` element. However, the semantic intent of `bluefin/` is bluefin-family only. When a package is placed there with a comment like "bluefin + bluefin-lts only", it creates ambiguity about whether Dakota gets it.

**Resolution:** `shared/preinstall.d/` is the unambiguous home for any package that is factory-wide. `bluefin/preinstall.d/` should only contain packages that are intentionally absent from Dakota.

**Concrete example:** `chairlift.Brewfile` lives in
`system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/`, making its
all-variant provisioning explicit.
