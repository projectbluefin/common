# DX-Next — install, remove, verify, and debug

DX-Next is an experimental developer stack for Bluefin / uBlue images: **Virt (libvirt)**, **Docker (rootless + rootfull)**, **DX-Tools** (Homebrew bundle + VS Code + flatpaks), **Incus**, and **Cockpit** — orchestrated via `gum` menus and shared shell libraries.

This document covers end-user flows, what gets installed where, health checks, troubleshooting, and development on **immutable Fedora** (Silverblue / Bluefin) where `/usr` is read-only.

---

## Table of contents

1. [What gets installed](#what-gets-installed)
2. [How to install](#how-to-install)
3. [Installation components (menu)](#installation-components-menu)
4. [Docker: two daemons and contexts](#docker-two-daemons-and-contexts)
5. [How to uninstall](#how-to-uninstall)
6. [Verification checklist](#verification-checklist)
7. [Debugging and non-interactive runs](#debugging-and-non-interactive-runs)
8. [Troubleshooting](#troubleshooting)
9. [File and script reference](#file-and-script-reference)
10. [Developing DX-Next](#developing-dx-next)

---

## What gets installed

| Component | What it does | Main artifacts |
|-----------|----------------|----------------|
| **DX groups** | Adds user to `libvirt`, `docker`, `incus-admin` | `/etc/sysusers.d/dx-groups.conf` |
| **Virt** | Libvirt/QEMU in Podman (`libvirt-dx`) | `/etc/containers/systemd/libvirt-dx.container`, `/run/libvirt-dx/libvirt-sock` |
| **Docker** | Rootless user daemon + rootfull `dockerd-dx` | `~/.config/systemd/user/docker.service`, `/etc/systemd/system/dockerd-dx.service` |
| **DX-Tools** | Homebrew bundle, VS Code cask, npm devcontainers CLI, flatpaks | `dx-next.Brewfile`, `~/.linuxbrew`, flatpaks |
| **Incus** | Incus in Podman (`incus-dx`) + Homebrew `incus` CLI | `/etc/containers/systemd/incus-dx.container`, `/var/lib/incus/unix.socket` |
| **Cockpit** | Cockpit WS in Podman (`cockpit-dx`) | `/etc/containers/systemd/cockpit-dx.container` |

**Note:** `incus` is **not** in the DX-Tools Brewfile; it is installed only when you select **Incus** in the menu (or run `ujust dx-incus` / `dx-next-dev.sh debug incus`).

Default install mode installs: **Virt**, **Docker**, **DX-Tools** (not Incus/Cockpit unless you customize).

---

## How `ujust` fits in

`ujust` is a thin wrapper around `just`:

```bash
# /usr/bin/ujust
just --justfile /usr/share/ublue-os/just/00-entry.just "$@"
```

Bluefin imports shared recipes from `00-entry.just`:

```just
import "/usr/share/ublue-os/just/apps.just"
```

The recipe **`dx-next`** in `apps.just` is what you run as:

```bash
ujust dx-next
```

Related commands (same PR / `dx.just`):

```bash
ujust dx-groups
ujust dx-tools
ujust dx-docker
ujust dx-virt
ujust dx-incus
ujust dx-cockpit
ujust dx-remove-all
ujust build-dx-next      # sysext image (optional)
ujust install-dx-next
```

**PR:** [projectbluefin/common#288](https://github.com/projectbluefin/common/pull/288) adds this stack. Until that layer is in your **rebased image**, `/usr/share/ublue-os/dx/` on the host may be missing or outdated — use the dev runners below.

---

## How to install

### On a shipped image (after PR is in `common` and the image is rebased)

```bash
ujust --list | grep dx-next    # should appear
ujust dx-next
```

Interactive menus: installation mode → component selection → one sudo password for the pass (with keepalive during long brew steps).

If DX-Next was **partially** installed (for example `dx-groups.conf` exists but VS Code and the sysext image are missing), the first menu says **“installation did not complete”** and offers the same choices as a full install: **Reinstall/Update**, **Remove**, or **Cancel** — not only a yes/no to continue setup.

### From this git repo (Silverblue / Bluefin — `/usr` read-only)

One dev script (same `apps.just` recipe as `ujust dx-next`):

```bash
./scripts/dx-next-dev.sh              # interactive
./scripts/dx-next-dev.sh link         # optional: ~/.local/bin/ujust-dx-next
```

Legacy wrappers still work: `run-dx-next-dev.sh`, `deploy-dx-next-fix.sh`, `debug-dx-next.sh` → see [scripts/README.md](../scripts/README.md).

### Temporary: put PR files on `/usr` with usroverlay (advanced)

On Fedora Atomic images that support it, you can overlay `/usr` once, copy files, then run real `ujust`:

```bash
sudo bootc usroverlay create   # or your image's documented usroverlay flow
./scripts/dx-next-dev.sh deploy system
ujust dx-next
# Reboot or discard overlay when done experimenting
```

Permanent fix: **rebase** to an image build that includes the merged `common` layer.

### Environment variables (install)

| Variable | Purpose |
|----------|---------|
| `DX_NONINTERACTIVE=1` | Skip gum menus |
| `DX_NEXT_CHOICES="Virt Docker DX-Tools Incus Cockpit"` | Components to install (with non-interactive) |
| `DX_SPIN_INLINE=1` | Run steps in the current shell with readable logs (default in dev script) |
| `DX_SPIN_SHOW_OUTPUT=1` | Show full brew output under spinners (noisy) |

Example — non-interactive install from repo:

```bash
cd /path/to/common
DX_NONINTERACTIVE=1 DX_NEXT_CHOICES="Virt Docker DX-Tools" ./scripts/dx-next-dev.sh run
```

### Per-component recipes (image with `dx.just` on PATH)

After libraries exist under `/usr/share/ublue-os/dx/`:

```bash
ujust dx-groups
ujust dx-tools
ujust dx-docker          # rootless, then rootfull
ujust dx-docker-rootless
ujust dx-docker-root
ujust dx-virt
ujust dx-incus
ujust dx-cockpit
ujust dx-apply Virt Docker   # groups + selected components in one shell
```

### After install

Reboot once so **sysusers** / group membership fully apply (groups often look correct before reboot, but reboot is still recommended).

---

## Installation components (menu)

| Menu choice | Install step | Skips when |
|-------------|--------------|------------|
| **Virt** | Flatpaks + `libvirt-dx` quadlet + firewall/udev | Unit already active and quadlet present |
| **Docker** | Rootless setup, then `dockerd-dx` | Rootless user service already running; rootfull unit enabled |
| **DX-Tools** | `brew bundle`, VS Code cask, extensions, flatpaks | Packages already present (idempotent) |
| **Incus** | `brew install incus` + `incus-dx` quadlet | Already configured |
| **Cockpit** | `cockpit-dx` quadlet | Already configured |

Progress lines look like:

```text
󱁯 Installing DX-Tools & Base Apps...
  → brew bundle (may take several minutes; downloading packages)...
  Done.
── DX-Tools ──
  VS Code CLI available
```

---

## Docker: two daemons and contexts

DX-Next installs **two** Docker engines:

| | Rootless | Rootfull (`dockerd-dx`) |
|---|----------|-------------------------|
| **Service** | `systemctl --user` `docker.service` | `systemctl` `dockerd-dx.service` |
| **Socket** | `unix:///run/user/$(id -u)/docker.sock` | `unix:///var/run/docker.sock` |
| **Context name** | `rootless` | `default` (after install) |
| **Data dir** | `~/.local/share/docker` | `/var/lib/docker` |

After install, the CLI default is **rootfull**:

```bash
docker context ls
docker context use default      # rootfull — system socket
docker context use rootless     # rootless — user socket
```

Check both:

```bash
docker info
docker -H "unix:///run/user/$(id -u)/docker.sock" info
```

Rootless `docker info` may show `WARNING: No cpuset support` — normal for rootless.

To prefer rootless daily:

```bash
docker context use rootless
# optional: add to ~/.bashrc
```

---

## How to uninstall

### Interactive (recommended)

```bash
ujust dx-next
# or
./scripts/dx-next-dev.sh run
```

When DX-Next is detected → **Remove** → **Remove all (Default)** or **Customize** (pick components).

You will be prompted for **sudo** once per removal pass (keepalive helps; long brew uninstall may still expire the ticket on slow runs).

### Non-interactive full remove

```bash
DX_NONINTERACTIVE=1 DX_NEXT_ACTION=remove ./scripts/dx-next-dev.sh run
```

### Per-component removal

```bash
ujust dx-remove-all
ujust dx-remove-docker
ujust dx-remove-virt
ujust dx-remove-tools
ujust dx-remove-incus
ujust dx-remove-cockpit
```

Or via debug script:

```bash
./scripts/dx-next-dev.sh debug remove --all
./scripts/dx-next-dev.sh debug remove --docker --virt
```

### What removal does

- Stops/disables systemd units (`*-dx`, user `docker.service`)
- Removes quadlet files under `/etc/containers/systemd/`
- Uninstalls Homebrew packages listed in the remove scripts (tools list **excludes** `incus`; use **Remove Incus** for that)
- Removes `/etc/sysusers.d/dx-groups.conf` on full remove
- May remove `/var/lib/extensions/dx-next.raw` if the sysext was installed

### After uninstall

Reboot, then confirm:

```bash
systemctl is-active libvirt-dx dockerd-dx incus-dx cockpit-dx
systemctl --user is-active docker.service
ls /etc/containers/systemd/*-dx.container /etc/sysusers.d/dx-groups.conf 2>&1
```

Expect **inactive** / **No such file** when removal succeeded.

---

## Verification checklist

### One-liner — services

Run this **alone** (not on the same line as another command):

```bash
printf 'libvirt-dx=%s dockerd-dx=%s incus-dx=%s cockpit-dx=%s user-docker=%s\n' \
  "$(systemctl is-active libvirt-dx 2>/dev/null || echo missing)" \
  "$(systemctl is-active dockerd-dx 2>/dev/null || echo missing)" \
  "$(systemctl is-active incus-dx 2>/dev/null || echo missing)" \
  "$(systemctl is-active cockpit-dx 2>/dev/null || echo missing)" \
  "$(systemctl --user is-active docker.service 2>/dev/null || echo missing)"
```

All selected components should show **active**.

### Config on disk

```bash
ls -la /etc/sysusers.d/dx-groups.conf
ls -la /etc/containers/systemd/*-dx.container
ls -la /etc/systemd/system/dockerd-dx.service
```

### Groups (after reboot)

```bash
groups
getent group libvirt docker incus-admin
```

### Docker

```bash
docker context ls
docker info
docker -H "unix:///run/user/$(id -u)/docker.sock" info
```

### DX-Tools

```bash
command -v code kind lima incus podman-compose
code --version
brew list --cask visual-studio-code-linux 2>/dev/null
flatpak list --app | grep -E 'virt-manager|flatpak.Builder|PodmanDesktop'
npm list -g @devcontainers/cli 2>/dev/null
```

### Virt

```bash
systemctl is-active libvirt-dx
ls -la /run/libvirt-dx/libvirt-sock
flatpak list --app | grep virt-manager
```

### Incus

```bash
incus version
systemctl is-active incus-dx
ls -la /var/lib/incus/unix.socket
```

### Cockpit

```bash
systemctl is-active cockpit-dx
systemctl status cockpit-dx --no-pager
```

Use `systemctl status …` for logs; `podman ps --filter name=cockpit` may be empty because the container name is not literally `cockpit`.

### Detailed status

```bash
systemctl status libvirt-dx dockerd-dx incus-dx cockpit-dx --no-pager
systemctl --user status docker.service --no-pager
journalctl -u dockerd-dx -u libvirt-dx -u incus-dx -u cockpit-dx -n 50 --no-pager
journalctl --user -u docker.service -n 50 --no-pager
```

---

## Debugging and non-interactive runs

### `dx-next-dev.sh debug`

No gum menus; uses the same libs and `dx_acquire_sudo` as `ujust dx-next`.

```bash
cd /path/to/common

./scripts/dx-next-dev.sh debug install Virt Docker
./scripts/dx-next-dev.sh debug install DX-Tools Incus Cockpit
./scripts/dx-next-dev.sh debug docker
./scripts/dx-next-dev.sh debug remove --all
```

### Dev runner flags

```bash
./scripts/dx-next-dev.sh run
DX_SPIN_INLINE=0 DX_SPIN_SHOW_OUTPUT=1 ./scripts/dx-next-dev.sh run
```

### Manual library sourcing

```bash
export DX_SHARE=/path/to/common/system_files/shared/usr/share/ublue-os/dx
export DX_UBLUE_ROOT=/path/to/common/system_files/shared/usr/share/ublue-os
source "$DX_SHARE/dx-ui-lib.sh"
source "$DX_SHARE/dx-install-lib.sh"
dx_acquire_sudo
dx_run_docker
```

### Sysext (optional image layer)

Some images support a **dx-next** system extension (separate from quadlet stack):

```bash
# from common repo root
just build-dx-next
just install-dx-next
```

Removal of `dx-next.raw` is included in `dx_remove_all_full` when the file exists.

---

## Troubleshooting

### `error: Recipe dx-next failed with exit code 127`

Usually a missing command in a **gum spin subprocess** (older builds). Current code runs steps **inline** (`DX_SPIN_INLINE=1`). Update the repo and use `scripts/dx-next-dev.sh`.

### Multiple sudo password prompts

Common after long **brew bundle** or rootless Docker download: TTY ticket expired.

- Use latest `dx-ui-lib.sh` (keepalive every 10s, `dx_extend_sudo_ticket` between Docker steps and before Virt/Incus/Cockpit).
- Run `sudo -v` once before starting if testing repeatedly.

### `brew link` failed for docker (target already exists)

Usually harmless; install continues with `brew link --overwrite`. If `docker` CLI is broken:

```bash
brew link --overwrite docker
```

### Rootless Docker setup failed but service is active

Install treats active `docker.service` as success. Check:

```bash
systemctl --user status docker.service
docker -H "unix:///run/user/$(id -u)/docker.sock" info
```

### Quadlet unit inactive

```bash
systemctl status libvirt-dx   # or incus-dx, cockpit-dx
journalctl -u libvirt-dx -b
podman ps -a
```

Regenerate/reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart libvirt-dx
```

### Incus CLI vs server version mismatch

`incus version` showing different client/server versions is normal when the CLI is Homebrew and the server runs in the `incus-dx` container image.

### Cannot write to `/usr` on Silverblue

Expected. Do **not** copy into `/usr` on an immutable host. Use:

```bash
./scripts/dx-next-dev.sh run
```

Permanent image fix: rebuild/rebase so `system_files/shared` ships in the OSTree.

### Removal left services running

Full remove should `stop`/`disable` units before deleting quadlets. If something persists:

```bash
sudo systemctl stop dockerd-dx libvirt-dx incus-dx cockpit-dx
sudo systemctl disable dockerd-dx libvirt-dx incus-dx cockpit-dx
systemctl --user stop docker.service
systemctl --user disable docker.service
podman rm -f libvirt-dx incus cockpit-ws 2>/dev/null || true
```

Then re-run remove or delete quadlet files manually.

---

## File and script reference

In-tree architecture notes (env vars, directory layout): [`system_files/shared/usr/share/ublue-os/dx/README.md`](../system_files/shared/usr/share/ublue-os/dx/README.md).

### User-facing entrypoints

| Path | Role |
|------|------|
| `ujust dx-next` | Main menu (`apps.just`) |
| `scripts/dx-next-dev.sh` | Dev install/remove (`run` / `deploy` / `debug` / `link`) |
| `scripts/lib/dx-paths.sh` | Shared path exports (sourced by dev script) |
| `scripts/run-dx-next-dev.sh` etc. | Thin wrappers → `dx-next-dev.sh` (compat) |
| `/usr/bin/dx-remove` | CLI wrapper → `dx_remove_main` |

### Libraries

| Path | Role |
|------|------|
| `dx/README.md` | Architecture diagram, env vars, dev overrides |
| `dx/dx-ui-lib.sh` | Messages, spinners, `dx_acquire_sudo`, `dx_sudo_run` |
| `dx/dx-install-lib.sh` | Install steps (`dx_run_*`, `dx_apply_choice`) |
| `dx/dx-remove-lib.sh` | Removal steps (`dx_remove_main`, flags) |
| `homebrew/dx-next.Brewfile` | DX-Tools bundle (no `incus`) |
| `dx/quadlets/*.container` | Podman quadlet definitions |
| `dx/units/system/dockerd-dx.service` | Rootfull Docker unit |

### Just recipes

| Recipe | Action |
|--------|--------|
| `dx-next` | Full interactive flow |
| `dx-groups`, `dx-tools`, `dx-docker`, … | Single component |
| `dx-remove-*` | Partial or full removal |
| `build-dx-next` / `install-dx-next` | Sysext image |

---

## Developing DX-Next

Source files use section comments (`# --- Docker ---`) in the shell libraries; non-obvious behavior (sudo TTY, single-shell sourcing, Brewfile vs Incus) is documented in file headers and in [`dx/README.md`](../system_files/shared/usr/share/ublue-os/dx/README.md).

1. Edit files under `system_files/shared/usr/share/ublue-os/dx/` and `just/apps.just`.
2. Test with `./scripts/dx-next-dev.sh` (no image rebuild).
3. Run `./scripts/dx-next-dev.sh debug …` for scripted installs.
4. For mutable VMs only: `./scripts/dx-next-dev.sh deploy system` then `ujust dx-next`.
5. Ship changes via image build / rebase for production Bluefin users.

Report issues: [projectbluefin/common](https://github.com/projectbluefin/common) · Discord linked in the install completion banner.

---

## Contributing (fork / PR #288)

Upstream PR: **https://github.com/projectbluefin/common/pull/288**

Typical workflow for **@repires** (or any fork):

```bash
cd common
git remote add upstream https://github.com/projectbluefin/common.git
git remote add origin https://github.com/repires/common.git   # your fork
git fetch upstream pull/288/head:pr-288
git checkout dxnext   # or your branch name
git merge pr-288        # sync with PR branch if needed

# work, commit, push
git push origin dxnext
# open or update PR against projectbluefin/common
```

### What the PR is expected to ship (from plan + review themes)

| Area | Intent |
|------|--------|
| **`apps.just` → `dx-next`** | Interactive install/remove menu (this doc) |
| **`dx.just`** | Per-component `ujust dx-*` recipes + `build-dx-next` / `install-dx-next` sysext with correct root ownership (`mksquashfs -all-root`) |
| **`dx/*.sh` libs** | Single-shell install/remove, sudo keepalive, quadlets under `DX_SHARE` |
| **`dx-remove`** | Modular removal (`--docker`, `--virt`, …, `--all`) |
| **Brewfile** | DX-Tools bundle; **Incus** installed only via menu / `dx-incus`, not Brewfile |

Commits on the `dxnext` branch in this workspace include themes like: libvirt gid hardening, docker cask/rootless fixes, incus-cli, modular remove, permission/sysext build fixes (`a8f01ae Change images permissions`, etc.).

### Checklist before merge

- [ ] `ujust dx-next` works on a **DX/dev image** with writable or overlaid `/usr`
- [ ] Silverblue testers can use `scripts/dx-next-dev.sh` until rebase
- [ ] `docs/dx-next.md` stays in sync with behavior
- [ ] No duplicate `incus` in Brewfile + Incus step

After merge: **bluefin-common** OCI layer picks up `system_files/shared/` → Bluefin image rebuild → users run **`ujust dx-next`** without the dev script.
