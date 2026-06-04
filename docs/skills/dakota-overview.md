---
name: dakota-overview
description: Use when you need context on what dakota/egg is, how it differs from production Bluefin, what unique features it has, what the known package gaps are, or when planning new package additions to the image
---

# Dakota (egg) Overview

## Powerlevel

- **Level:** 1

Load with: `cat ~/src/skills/dakota-overview/SKILL.md`

## When to Use

- Understanding what dakota/egg is and how it differs from production Bluefin
- Planning new package additions by checking the gap analysis
- Explaining the build architecture, unique features, or intentional gaps to a contributor
- Deciding whether a package belongs in egg or is out of scope

## When NOT to Use

- Authoring `.bst` element files → use `dakota-buildstream` or `dakota-add-package`
- Debugging CI pipeline failures → use `dakota-ci`
- Looking up specific packaging patterns → use the relevant `dakota-package-*` skill

## ⛔ Hard Facts — Violations Recorded 3+ Times

**Dakota runtime is composefs. It is NOT OSTree.**
- The BST export includes `/sysroot/` artifacts (OSTree build leftovers) — `--prune /sysroot/` strips them at rechunking time.
- The booted system uses the composefs-oci backend. There is no ostree runtime on the running NUC.
- Never suggest OSTree-specific tooling (bootupd, ostree admin, rpm-ostree) for a running dakota system.

**zstd:chunked is disabled. Plain podman push is correct.**
- zstd:chunked was tested on 2026-04-18 (issue castrojo/dakota#119) and fails with bootc composefs ("unexpected EOF reading tar entry") regardless of flags or annotation stripping.
- After chunkah rechunking (`chunkah build → podman load`), blobs in containers-storage are fresh and uncompressed — plain `podman push` is the correct and upstream-recommended path.
- Do not reintroduce skopeo, `--compression-format=zstd:chunked`, or any oci-dir workaround for post-chunkah pushes. Read issue #119 before asserting anything about push compression.

**No upstream PR before NUC hardware confirms.**
- The validation gate is: `bootc upgrade` on NUC (192.168.1.247) succeeds + reboot + GDM active.
- "Tests pass on ghost" or "CI is green in castrojo fork" is NOT sufficient. Only NUC confirmation is.

**Production image = `ghcr.io/projectbluefin/dakota:latest`. NUC ≠ production.**
- The NUC (192.168.1.247) runs a local/custom image built from ghost. It is NOT the production GHCR image.
- When the user says "the image" or "is X in the image", always check `ghcr.io/projectbluefin/dakota:latest` via `skopeo inspect` or `podman run --rm` — do NOT check the NUC unless the user explicitly says "on the NUC".

**Verify hypothesis before stating root cause.**
- When investigating a missing package or regression, state it as a hypothesis ("likely cause is X") until confirmed by live evidence.
- Do not announce the root cause (e.g., "Classic BST weak-key caching bug") before reading the git log or build output that proves it.

## What Is Dakota?

Dakota (internal build codename **egg**) is Project Bluefin's **CoreOS-model bootc image** — built entirely from source using **BuildStream 2**. It follows the same architecture as CoreOS and GNOME OS: bootc-native from day one, composefs runtime, no OSTree, no rpm-ostree, no dnf.

freeddesktop-sdk provides glibc/systemd/kernel, gnome-build-meta provides GNOME Shell/Mutter/GTK, and dakota adds Bluefin-specific packages on top.

**Key positioning:** egg is a **curated subset** of production Bluefin, not a 1:1 clone. It intentionally includes things production Bluefin doesn't have (sudo-rs, uutils-coreutils, GNOME nightly) and intentionally omits things that don't make sense for a from-source build (Nvidia drivers, ZFS, enterprise AD/Kerberos).

Published image: `ghcr.io/projectbluefin/dakota:latest`

## Architecture Comparison

| Dimension | **egg (dakota)** | **bluefin** | **bluefin-lts** |
|---|---|---|---|
| **Base** | freedesktop-sdk + gnome-build-meta (from source) | Fedora Silverblue (pre-built RPMs) | CentOS Stream 10 (pre-built RPMs) |
| **Build system** | BuildStream 2 (hermetic sandbox builds) | Containerfile + `dnf install` | Containerfile + `dnf install` |
| **Build time** | 120 min CI timeout, heavy | ~30-60 min CI | ~45-60 min CI |
| **Disk required** | **>50 GB** (BuildStream CAS) | ~15-20 GB | ~15-20 GB |
| **Desktop** | GNOME (nightly/latest) | GNOME (Fedora's version) | GNOME 48 (pinned via COPR) |
| **Kernel** | freedesktop-sdk kernel | Fedora kernel + akmods | CentOS kernel + akmods |
| **Update model** | `bootc` (native) | `rpm-ostree` (migrating to bootc) | `bootc` (native) |
| **Package count** | ~20 Bluefin-specific elements | ~80 base + ~60 DX RPMs | ~80 base + DX/GDX RPMs |
| **Architectures** | x86_64, aarch64, riscv64 | x86_64 primarily | x86_64, aarch64 |
| **Variants** | Single image | bluefin, bluefin-dx, nvidia | base, dx, gdx, HWE, nvidia |

### Fundamental Difference

Production Bluefin images are **Containerfile-based overlays** — they start with `FROM base_image` and run `dnf install` to add ~80-140 pre-built RPMs. Total build is 30-60 minutes on 15-20 GB disk. They never compile anything from source except 7 GNOME Shell extensions.

Egg **builds the entire stack from source** using BuildStream. With good cache hits from the upstream CAS, most is pre-built. But Bluefin-specific Rust packages (bootc, uutils-coreutils, sudo-rs) and GRUB are compiled from source, making the build substantially heavier.

## What Egg Has That Others Don't

| Egg Unique Feature | Notes |
|---|---|
| **sudo-rs** (Rust sudo) | Memory-safe sudo replacement — not in any production Bluefin |
| **uutils-coreutils** (Rust coreutils) | Memory-safe coreutils — not in any production Bluefin |
| **Built entirely from source** | Reproducible, auditable, no RPM dependency |
| **GNOME nightly** | Latest GNOME, ahead of Fedora |
| **riscv64 support** | Neither bluefin nor bluefin-lts supports this |

## Gap Analysis: What Egg Is Missing

Gaps as of 2026-02-15. Y = present, N = absent.

### GNOME Shell Extensions

| Extension | egg | bluefin | bluefin-lts |
|---|:---:|:---:|:---:|
| AppIndicator | Y | Y | Y |
| Blur My Shell | Y | Y | Y |
| Caffeine | Y | Y | Y |
| Dash to Dock | Y | Y | Y |
| Gradia (screen capture) | Y (2026-05-22) | N | N |
| GSConnect | Y | Y | Y |
| Logo Menu | Y | Y | Y |
| Search Light | Y | Y | Y |

### Shell & Terminal Tools

| Package | egg | bluefin | bluefin-lts |
|---|:---:|:---:|:---:|
| just | Y | Y | Y |
| wl-clipboard | Y | Y | Y |
| glow | Y | Y | Y |
| gum | Y | Y | Y |
| fzf | Y | Y | Y |
| fish | N | Y | N |
| zsh | N | Y | N |
| tmux | N | Y | N |
| Starship prompt | N | Y | N |
| fastfetch | N | Y | Y |
| xdg-terminal-exec | N | Y | Y |

### Networking & VPN

| Package | egg | bluefin | bluefin-lts |
|---|:---:|:---:|:---:|
| Tailscale | Y | Y | Y |
| wireguard-tools | N | Y | Y |
| samba | N | Y | N |
| NM-openvpn | N | N | Y |

### Containers

| Package | egg | bluefin | bluefin-lts |
|---|:---:|:---:|:---:|
| podman | Y | Y | Y |
| skopeo | Y | Y | Y |
| distrobox | Y | N | Y |
| containerd | N | Y | Y |
| buildah | N | N | Y |

### Hardware & Drivers (Intentionally Out of Scope)

| Feature | egg | bluefin | bluefin-lts |
|---|:---:|:---:|:---:|
| Nvidia drivers | N | Y (variant) | Y (GDX variant) |
| ZFS | N | Y | Y |
| Xbox controller (xone) | N | Y | Y (HWE) |
| Framework laptop modules | N | Y | Y (HWE) |
| v4l2loopback | N | Y | Y (HWE) |

### Other Notable Gaps (Priority Order)

| Package | Priority | Notes |
|---|---|---|
| fastfetch | Future | System info tool, in both production Bluefins |
| Starship prompt | Future | Shell prompt, core Bluefin UX; pre-built binary |
| fish shell | Future | Alternative shell; requires build from source |
| fwupd | Future | Firmware updates; upstream element exists |
| adw-gtk3-theme | Future | GTK3 app theming consistency |
| uupd (auto-updater) | Future (complex) | Upstream OTA update daemon |
| Bazaar (app store) | Future (complex) | Flatpak-based app store |
| **Albert launcher** | Future (multi-session) | Qt6-based keyboard launcher — see note below |
| AD/Kerberos/SSSD | Probably never | Enterprise auth — outside egg's scope |

### Albert Launcher — Packaging Notes (researched 2026-05-23)

- **Flatpak: dead end** — upstream README says "dysfunctional prototype, Flatpak does not provide permissions to run albert in a way that makes sense for a launcher". Not on Flathub, never will be.
- **Published via**: OBS (`build.opensuse.org/home:manuelschneid3r`) only.
- **Only frontend**: `widgetsboxmodel` (Qt Widgets + QStyleSheets). QML frontend (`qmlboxmodel`) was archived and removed.
- **Theming**: QStyleSheet CSS files. System dark/light needs `qgnomeplatform-qt6` (not in BST stack) + a theme-watcher service.
- **Keybinding**: Super+S via dconf override (trivial once Albert is packaged).

**7 new BST elements required** (none of these are in freedesktop-sdk or gnome-build-meta):

| Element | Notes |
|---|---|
| `qt6base.bst` | Heaviest — Core, Widgets, Network, Sql, Concurrent, GUI |
| `qt6svg.bst` | Depends on qt6base |
| `qt6scxml.bst` | Depends on qt6base |
| `qt6tools.bst` | lupdate/lrelease for i18n |
| `qcoro6.bst` | Qt async coroutines — hard required |
| `qtkeychain.bst` | Secure credential storage — easy to miss |
| `albert.bst` | CMake + C++23 + git submodule plugins (~28 plugins) |

Deps already in freedesktop-sdk: `libarchive`, `libxml2`, `python3`, `libgl/mesa`. Optional: `libqalculate` (calculator plugin, can disable).

Recommended session split: Session 1 (qt6base + qt6svg), Session 2 (remaining Qt6 + qcoro6 + qtkeychain), Session 3 (albert + dconf keybinding + lab test).

## Build Optimization Notes

Heavy build contributors:

1. **Rust packages** — bootc (~200 crates), uutils-coreutils (~250 crates), sudo-rs. Decision: keep building from source — these are the crown jewels of egg's approach.
2. **GRUB** — built in 3 variants (i386-pc, i386-efi, x86_64-efi). Required because upstream GNOME OS uses systemd-boot only; Bluefin needs GRUB for bootc compatibility.
3. **Junction patches** — 8 patches to freedesktop-sdk, 1 to gnome-build-meta. These modify the junction identity hash which may affect upstream cache hit rates. Upstreaming patches would improve this.
4. **Pre-built binary pattern** — already used successfully for Tailscale, Zig, Homebrew, Go CLI tools. New packages should follow this pattern where possible.

## Cross-References

| Skill | When |
|---|---|
| `dakota-buildstream` | Writing or modifying `.bst` elements |
| `dakota-add-package` | Adding a new package to the image |
| `dakota-oci-layers` | Understanding the image layer structure |
| `dakota-local-ota` | Running a local OTA update registry for dev |
| `dakota-ci` | Understanding or debugging the CI pipeline |
