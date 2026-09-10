---
name: devmode
version: "1.0"
last_updated: "2026-06-23"
id: devmode
one_line_purpose: Configure the Bluefin Developer Mode setup wizard.
entry_point: docs/skills/devmode.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [devmode, development, debugging]
description: >-
  Bluefin Developer Mode setup wizard. Use when working on devmode docs, UX,
  tool selection, or the canonical ujust devmode command.
metadata:
  type: procedure
---

# devmode — Turn on Developer Mode

## When to Use

- Updating docs or UX around Bluefin Developer Mode
- Verifying the canonical user-facing command for developer setup
- Checking what the devmode wizard installs and how it behaves
- Auditing legacy `-dx` references or stale rebase guidance

## When NOT to Use

- Writing Dakota-specific overrides — Dakota should fall through to common unless there is a real Dakota-only need
- Documenting `ujust toggle-devmode` as the primary user-facing command
- Recommending `rpm-ostree install` as a fallback for Developer Mode tooling
- Describing any Developer Mode flow as a rebase to a `-dx` image

## What this is

`ujust devmode` is a local setup wizard that installs a developer stack on any Bluefin image in-place. **There is no -dx image rebase.** The -dx image variant is retired.

File: `system_files/bluefin/usr/share/ublue-os/just/system.just`

`ujust toggle-devmode` is a legacy compatibility name. Docs and UX should point users to `ujust devmode`.

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

## VS Code defaults

- Keep VS Code extensions in `system_files/shared/usr/share/ublue-os/homebrew/ide.Brewfile` using `vscode "publisher.extension"` entries instead of a post-install shell hook.
- The only VS Code config we ship in the image is the default `settings.json` at `system_files/bluefin/etc/skel/.config/Code/User/settings.json`.

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
- **incus via brew**: incus is installed via `brew install incus` inside the devmode wizard. If Homebrew is unavailable or that install step fails, the wizard fails at that step. There is no separate recipe and no fallback.
- **`gum choose --no-limit` section headers**: header strings (e.g. `── Docker ───`) are selectable items. They are filtered out in the summary/install logic by using specific `grep -q` patterns that don't match header text. Do not use item names that are substrings of header text.

---

## Core Process

1. Treat `ujust devmode` as the canonical entrypoint; only mention `toggle-devmode` as legacy compatibility context.
2. Verify the current implementation in `system_files/bluefin/usr/share/ublue-os/just/system.just` before documenting behavior.
3. Describe Developer Mode as an in-place setup flow: `ujust devmode` opens the gum wizard.
4. Document optional tools exactly as the wizard presents them, including incus via `brew install incus`.
5. Reject stale fallbacks: no `setup-incus` recipe, no `rpm-ostree install`, no `incus-distrobox` guidance.
6. If touching downstream overrides, prefer removing stale overrides so common's implementation remains the source of truth.

## Common Rationalizations

- **"`toggle-devmode` is still there, so docs can recommend it."**
  No. It is a compatibility name, not the canonical UX.
- **"If brew fails we should tell users to layer packages."**
  No. Bluefin docs should not recommend `rpm-ostree install` as the escape hatch here.
- **"Developer Mode means rebasing to a special image."**
  No. The `-dx` image path is retired.

## Red Flags

- Docs that tell users to run `ujust toggle-devmode`
- Any mention of a `setup-incus` recipe
- Any `rpm-ostree install incus` fallback
- Any suggestion that Developer Mode rebases to a `-dx` image
- Dakota-specific docs or overrides that assume `dakota-dx` exists

## Verification

- [ ] User-facing docs recommend `ujust devmode`, not `ujust toggle-devmode`
- [ ] No docs mention `setup-incus`
- [ ] No docs recommend `rpm-ostree install` for Developer Mode tooling
- [ ] Bluefin Developer Mode is described as in-place setup, not image rebasing
- [ ] Any downstream override still matches common's current implementation or is removed

---

## PR history

- PR #545 (`feat/devmode-wizard`) — initial implementation, closes issue #103
- PR #544 (`feat/setup-vms-recipe`) — superseded; `setup-vms` and `toggle-vms` recipes incorporated here
