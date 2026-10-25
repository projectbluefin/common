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
- Anything naturally opt-in (`k8s-tools`, `cncf`, `ide`, …) — those go in the
  opt-in Brewfiles below
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

## Opt-in Brewfiles

These live in `system_files/shared/usr/share/ublue-os/homebrew/` (not in
`preinstall.d/`). **There is no `ujust bbrew` recipe** — the string `bbrew`
appears nowhere in the `Justfile` or in `system_files/`. Only two of these
Brewfiles have a recipe at all:

| Brewfile | Install path |
|---|---|
| `cli.Brewfile` | `ujust bluefin-cli` (`system.just:39`) |
| `cncf.Brewfile` | `ujust cncf` (`apps.just:55`) |
| `ai-tools.Brewfile` | none |
| `artwork.Brewfile` | none |
| `experimental-ide.Brewfile` | none |
| `fonts.Brewfile` | none |
| `fonts-dev.Brewfile` | none |
| `ide.Brewfile` | none |
| `k8s-tools.Brewfile` | none |
| `swift.Brewfile` | none |

The eight with no recipe are installed only by running `brew bundle` by hand:

```bash
brew bundle --file=/usr/share/ublue-os/homebrew/k8s-tools.Brewfile
```

They are shipped, validated, and otherwise unreachable. Either give them a
recipe or stop shipping them; do not document a menu that does not exist.

Bluefin-specific, in `system_files/bluefin/usr/share/ublue-os/homebrew/`:

| Brewfile | Install path |
|---|---|
| `system-flatpaks.Brewfile` | `ujust install-system-flatpaks` (`system.just:299`) |
| `full-desktop.Brewfile` | none |
| `system-dx-flatpaks.Brewfile` | none — orphaned by the `-dx` retirement; see [`devmode.md`](../../devmode.md) |

### `cli.Brewfile` overlaps the managed set

`cli.Brewfile` declares `starship`, which every user already has from
`preinstall.d/system-cli.Brewfile`. Running `ujust bluefin-cli` re-declares a
package the OS manages. Harmless to Homebrew, but it means `bluefin-cli` no
longer describes a purely opt-in set. `mise` is the genuinely new entry — it is
what `bling.sh` activates when present (honouring `MISE_BASH_AUTO_ACTIVATE=0`
and `MISE_ZSH_AUTO_ACTIVATE=0`).

### Validation scope

`scripts/validate-brewfiles.sh` and the `validate-brewfiles.yaml` workflow
default to `system_files/shared/usr/share/ublue-os/homebrew`. The three
Brewfiles under `system_files/bluefin/` are **not** validated. Offline
regression suite: `bats tests/test_validate_brewfiles.bats`.

---

## Brewfile scope: shared/ vs bluefin/ for all-variant packages

**Rule:** any package that should install on ALL variants (bluefin, bluefin-lts,
dakota) belongs in
`system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/`, never in a
`preinstall.d/` under `system_files/bluefin/`.

`system_files/bluefin/` is consumed by bluefin and bluefin-lts, and dakota also
pulls it in via its `common.bst` element — so a package placed there *does*
reach dakota, despite the directory name implying otherwise. That ambiguity is
the whole problem. Putting it under `shared/` states the intent unambiguously.

As of today there is no `preinstall.d/` under `system_files/bluefin/` at all,
and both managed Brewfiles — `system-cli.Brewfile` and `chairlift.Brewfile` —
live under `shared/`. Keep it that way unless a package must be genuinely
absent from dakota.
