# devmode — Turn on Developer Mode

## What this is

`ujust devmode` (alias: `ujust toggle-devmode`) is a local setup wizard that installs a developer stack on any Bluefin image in-place. **There is no -dx image rebase.** The -dx image variant is retired.

File: `system_files/bluefin/usr/share/ublue-os/just/system.just`

---

## What it installs

### Always
- `devcontainer` CLI (brew) — central to the dx workflow for all editors

### User-selectable (single `gum choose --no-limit` screen)

| Section | Item | What it installs |
|---|---|---|
| Docker | Docker | docker + docker-compose + lazydocker + dive |
| Podman | Podman Desktop | flatpak `io.podman_desktop.PodmanDesktop` |
| Virtualization | Virtual Machines | flatpak virt-manager + QEMU extension |
| Virtualization | incus | brew install incus (see caveat below) |
| IDE | VS Code | `ublue-os/tap/visual-studio-code-linux` |
| IDE | VSCodium | `ublue-os/tap/vscodium-linux` |
| IDE | Antigravity | `ublue-os/tap/antigravity-linux` |
| IDE | Zed | `ublue-os/experimental-tap/zed-linux` |
| IDE | JetBrains Toolbox | `ublue-os/tap/jetbrains-toolbox-linux` |
| CLI Editors | Neovim | brew nvim |
| CLI Editors | Helix | brew helix |
| CLI Editors | vim | brew vim |
| CLI Editors | micro | brew micro |

Docker and Podman Desktop are **pre-selected** by default.

---

## UX flow

```
Title box
  → gum choose --no-limit  (single screen, section headers)
  → summary box (what will be installed)
  → "Install now?" confirm
  → gum spin progress per package
  → pkexec group setup (conditional on selection)
  → marker file written to ~/.config/bluefin/devmode
  → done box
```

Re-running when marker exists shows "already configured, add more tools?" prompt.

---

## Groups

Groups are added via `pkexec` at the end, conditional on what was selected:

| Package | Group added |
|---|---|
| Docker | `docker` |
| Virtual Machines | `libvirt` |
| incus | `incus-admin` |
| Always | `dialout` |

`dx-group` remains as a standalone recipe for manual use.

---

## Tap strategy

- `ublue-os/tap` — tapped once if any of VS Code / VSCodium / Antigravity / JetBrains selected
- `ublue-os/experimental-tap` — tapped once if Zed selected

---

## State tracking

- Marker: `~/.config/bluefin/devmode`
- Touch on completion, checked on re-entry
- No full uninstall path — individual `ujust toggle-vms`, `brew uninstall`, etc.

---

## Legacy -dx image users

If `IMAGE_NAME` ends in `dx`, the wizard shows an advisory:
> "Legacy -dx image detected. After setup, run 'bootc switch ghcr.io/projectbluefin/bluefin:stable' to switch to the standard image."

The wizard still runs normally — it does NOT rebase automatically.

---

## `install-system-flatpaks` fix

The old `image-flavor =~ dx` gate was removed. That gate was dead once the -dx image retired — it would silently skip all dev flatpaks forever. The recipe now installs `system-flatpaks.Brewfile` only (no dx split).

---

## Known caveats

- **Docker daemon**: `brew install docker` provides the CLI. The `moby-engine` daemon must be present in the base image as a layered system package. If `dockerd` is missing, docker CLI works but containers won't run. Verify moby is in the Containerfile before shipping.
- **incus via brew**: availability on Linuxbrew is not guaranteed. The `setup-incus` recipe falls back gracefully with instructions to `rpm-ostree install incus` if brew fails.
- **`gum choose --no-limit` section headers**: header strings (e.g. `── Docker ───`) are selectable items. They are filtered out in the summary/install logic by using specific `grep -q` patterns that don't match header text. Do not use item names that are substrings of header text.

---

## PR history

- PR #545 (`feat/devmode-wizard`) — initial implementation, closes issue #103
- PR #544 (`feat/setup-vms-recipe`) — superseded; `setup-vms` and `toggle-vms` recipes incorporated here
