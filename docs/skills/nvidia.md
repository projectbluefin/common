---
name: nvidia
version: "1.0"
last_updated: 2026-06-23
tags: [nvidia, gpu, drivers, akmods]
description: "NVIDIA GPU support architecture, CDI-first container model, per-repo responsibilities, driver/toolkit version updates, and flatpak runtime sync. Use when editing any nvidia-related file in system_files/nvidia/, bluefin build scripts, bluefin-lts nvidia overlay, or dakota nvidia elements."
metadata:
  type: reference
---

# NVIDIA GPU Support — Agent Skill

## When to Use

- Editing `system_files/nvidia/` in `projectbluefin/common`
- Modifying nvidia build scripts in `bluefin`, `bluefin-lts`, or `dakota`
- Updating NVIDIA driver or container toolkit versions
- Debugging flatpak GPU access or CDI spec generation failures
- Adding new nvidia-related services or presets

## When NOT to Use

- Filing issues or making changes in `ublue-os/*` — tell the human to report upstream manually
- Modifying the closed-source driver path — factory only ships open kernel modules (Turing+)

## What this covers

The factory ships NVIDIA GPU support across three image lineages. This skill covers the
architecture, the CDI-first container model, per-repo responsibilities, how to update the
driver or toolkit version, and known constraints.

---

## The three repos and their nvidia stacks

| Repo | Base OS | Driver source | NCT installed | CDI preset |
|---|---|---|---|---|
| `projectbluefin/common` | shared overlay | — | — | ✅ `system_files/nvidia/…/80-nvidia-container-toolkit.preset` |
| `projectbluefin/bluefin` | Fedora | `ublue-os/akmods-nvidia-open` OCI | ✅ (build script) | inherits from common |
| `projectbluefin/bluefin-lts` | CentOS Stream 10 | `ublue-os/akmods-nvidia-open` OCI | ✅ (nvidia build overlay) | ✅ `system_files_overrides/gdx/…/80-nvidia-container-toolkit.preset` |
| `projectbluefin/dakota` | GNOME OS (BST) | `.run` installer, open kmod | ✅ (built from source) | ✅ `elements/bluefin-nvidia/nvidia-container-toolkit-preset.bst` |

**dakota is the reference implementation.** When in doubt about the correct approach for
nvidia-related changes, read `elements/bluefin-nvidia/` in dakota first.

---

## CDI is the architecture — not OCI hooks

Container GPU access uses **CDI (Container Device Interface)**, not the legacy nvidia OCI
hook. This is the correct approach for bootc/immutable/rootless systems.

### How CDI works on bluefin

1. `nvidia-container-toolkit-base` ships two binaries: `nvidia-ctk` and `nvidia-cdi-hook`
2. `nvidia-cdi-refresh.service` runs `nvidia-ctk cdi generate` at boot → writes `/var/run/cdi/nvidia.yaml`
3. `nvidia-cdi-refresh.path` watches `/lib/modules/*/modules.dep` and `/usr/bin/nvidia-ctk`;
   triggers the service on driver or toolkit changes
4. The systemd preset (`80-nvidia-container-toolkit.preset`) enables both units at first boot
5. Podman v4.1.0+ speaks CDI natively: `podman run --device nvidia.com/gpu=all --security-opt=label=disable ...`

The CDI spec lives at `/var/run/cdi/nvidia.yaml` — this is tmpfs (ephemeral). It is
regenerated on every boot by the service. Do not try to bake it into the image.

### What NOT to install

Do **not** install:
- `nvidia-container-runtime` — the legacy OCI runtime wrapper; not needed with CDI
- `libnvidia-container1` / `libnvidia-container-tools` — used only by the OCI hook path
- `nvidia-container-toolkit` (full package) — pulls in the OCI hook; use `-base` variant
- The OCI hook file `/usr/share/containers/oci/hooks.d/oci-nvidia-hook.json` — conflicts with CDI

Dakota's `nvidia-container-toolkit.bst` is explicit: *"We do not ship nvidia-container-runtime
or libnvidia-container."* Follow that lead in all repos.

### Rootless config

After installing `nvidia-container-toolkit-base`, run:
```bash
nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place
```
This writes to `/etc/nvidia-container-runtime/config.toml`. Without it, rootless Podman
containers fail to access GPUs because bootc does not use cgroup device delegation.

---

## Per-repo: where nvidia code lives

### `projectbluefin/common`

- `system_files/nvidia/usr/libexec/ublue-nvidia-flatpak-runtime-sync` — syncs the correct
  `org.freedesktop.Platform.GL.nvidia-<version>` Flatpak runtime when a new driver version
  is detected on boot. Also runs `flatpak update --system --noninteractive` in the same pass
  so all system Flatpaks are current after rebooting into a new NVIDIA image (not just the GL
  extension). Needed for Flatpak apps to use the GPU. Triggered by
  `ublue-nvidia-flatpak-runtime-sync.service` (TimeoutStartSec=900).
- `system_files/nvidia/usr/lib/systemd/system-preset/80-nvidia-container-toolkit.preset` —
  enables `nvidia-cdi-refresh.{path,service}` for CDI spec auto-generation.

Changes here flow into **all** nvidia-variant images at next build. Be surgical.

### `projectbluefin/bluefin`

- `build_files/base/04-install-kernel-akmods.sh` — the nvidia build block
  (guarded by `if [[ "${IMAGE_NAME}" =~ nvidia ]]`)

Key steps in that block:
1. Pulls `ghcr.io/ublue-os/akmods-nvidia-open:<flavor>-<fedora>-<kernel>` OCI at build time
2. Excludes `golang-github-nvidia-container-toolkit` (Fedora's Go rewrite — different package,
   not what we want)
3. Imports `ublue-os/staging` COPR GPG key (required before enabling that COPR on Fedora 44+)
4. Runs `ublue-os/nvidia-install.sh` from the akmods bundle (installs kmod, vulkan, kargs)
5. Installs `nvidia-container-toolkit-base` from NVIDIA's official RPM repo
6. Configures rootless CDI
7. Removes the NVIDIA toolkit repo file from the final image

The `golang-github-nvidia-container-toolkit` exclusion is intentional — it is Fedora's
community Go rewrite and a different package from NVIDIA's official C toolkit. Keep the
exclusion even after adding the official toolkit.

### `projectbluefin/bluefin-lts` (nvidia build overlay)

`gdx/` is the internal build override directory name for the nvidia stack in LTS — it is not a user-facing variant or image name.

- `build_scripts/overrides/gdx/20-nvidia.sh` — nvidia install script
- `system_files_overrides/gdx/usr/lib/systemd/system-preset/80-nvidia-container-toolkit.preset`

The LTS build uses an override directory system. `build.sh` calls `run_buildscripts_for gdx`
(runs `build_scripts/overrides/gdx/*.sh`) and `copy_systemfiles_for gdx` (copies
`system_files_overrides/gdx/` to `/`). Nvidia changes for LTS go in those two locations.

The LTS build installs the *full* `nvidia-container-toolkit` package (not `-base`) from the
`fedora-nvidia` repo that the akmods bundle enables. This is pre-existing behavior; don't
change the package selection without testing the nvidia LTS build.

### `projectbluefin/dakota`

Dakota uses BuildStream. Every nvidia component is a `.bst` element:

```
elements/bluefin-nvidia/
  deps.bst                         # stack: pulls all nvidia deps
  nvidia-drivers.bst               # .run installer → open kmod, Turing+ only
  nvidia-container-toolkit.bst     # builds nvidia-ctk + nvidia-cdi-hook from source
  nvidia-container-toolkit-preset.bst  # systemd preset enabling cdi-refresh units
  egl-external-platform.bst
  nvidia-egl-wayland.bst
  nvidia-kargs.bst
  nvidia-modprobe-config.bst
```

To bump the toolkit version in dakota: change `ref:` in `nvidia-container-toolkit.bst`
to the new tagged commit SHA. To bump the driver: change `url`, `ref` (sha256), and
`nvidia-version` in `nvidia-drivers.bst`.

---

## NGC container ecosystem — what users can run

After CDI is wired, users can pull and run any NVIDIA NGC container:

```bash
# Verify CDI is live
nvidia-ctk cdi list

# Run any NGC image
podman run --rm \
  --device nvidia.com/gpu=all \
  --security-opt=label=disable \
  nvcr.io/nvidia/cuda:12.4.1-base-ubuntu22.04 \
  nvidia-smi -L
```

### Key NGC containers

| Container | Pull | What's in it |
|---|---|---|
| CUDA base | `nvcr.io/nvidia/cuda:12.x.x-base-ubuntu22.04` | CUDA runtime only |
| CUDA devel | `nvcr.io/nvidia/cuda:12.x.x-devel-ubuntu22.04` | nvcc, headers, full dev stack |
| PyTorch | `nvcr.io/nvidia/pytorch:25.xx-py3` | CUDA + cuDNN + NCCL + Apex |
| TensorFlow | `nvcr.io/nvidia/tensorflow:25.xx-tf2-py3` | TF2 + XLA + TensorRT |
| JAX | `nvcr.io/nvidia/jax:latest` | JAX + XLA + multi-GPU |
| Triton | `nvcr.io/nvidia/tritonserver:25.xx-py3` | Multi-framework inference |
| RAPIDS | `nvcr.io/nvidian/rapidsai/rapids:25.xx` | cuDF, cuML, cuGraph |
| NeMo | `nvcr.io/nvidia/nemo:25.xx` | LLM training (GPT, LLaMA) |

NGC uses monthly release trains (25.04, 25.05, …). The host driver version must be ≥ the
CUDA version inside the container.

### Distrobox path (zero host changes)

For users who want NGC containers without waiting for the image stack:
```bash
distrobox create --name cuda-dev --image nvcr.io/nvidia/pytorch:25.04-py3 --nvidia
distrobox enter cuda-dev
```

---

## SELinux and CDI

Running NGC containers requires `--security-opt=label=disable` with Podman + CDI.
This is documented in NVIDIA's own CDI guide and is expected behavior — SELinux labels
on `/dev/nvidia*` and the driver lib mounts conflict with the default container label.

A proper SELinux policy module for nvidia CDI devices is a future improvement.

---

## Updating driver or toolkit versions

### bluefin / bluefin-lts

The driver version is controlled by `ublue-os/akmods` upstream. To pick up a new driver:
1. Wait for `ghcr.io/ublue-os/akmods-nvidia-open:<flavor>-<fedora>-<kernel>` to update
2. Renovate or a manual PR bumps the `KERNEL` ARG in the Containerfile, which pulls the
   matching akmods OCI
3. The driver version in the image tracks the akmods bundle automatically

To update `nvidia-container-toolkit-base` in bluefin: it comes from NVIDIA's official RPM
repo and is installed without version pinning, so it tracks latest stable automatically
on each image rebuild. If a specific version is needed:
```bash
dnf5 -y install nvidia-container-toolkit-base-${VERSION}
```

### dakota

Update `ref:` in `elements/bluefin-nvidia/nvidia-container-toolkit.bst` to the new tagged
commit SHA from `github:NVIDIA/nvidia-container-toolkit.git`. Driver bump: see that element.

---

## Constraints

- **Turing+ only (GTX 16xx, RTX 20xx+)** for open kernel modules. Pascal and earlier need
  the closed-source module which the factory does not ship.
- **CDI spec is runtime-only** — `/var/run/cdi/nvidia.yaml` lives on tmpfs and cannot be
  baked into the image. The `nvidia-cdi-refresh.service` regenerates it on every boot.
- **No cross-repo writes to `ublue-os/*`** — if the akmods bundle needs a change, report
  it to a human who will file an issue upstream manually.
- **`golang-github-nvidia-container-toolkit` exclusion** in bluefin is intentional. It is
  Fedora's Go rewrite of NCT and is a different package from NVIDIA's official C toolkit.
  Do not remove the exclusion.

---

## Verification

Before closing any nvidia-related PR:

- [ ] Changes to `system_files/nvidia/` tested to not break non-nvidia builds (shared layer affects all variants)
- [ ] No `ublue-os/*` repos were written to (file upstream issues manually)
- [ ] CDI preset not accidentally removed — `80-nvidia-container-toolkit.preset` still enables `nvidia-cdi-refresh.{path,service}`
- [ ] If editing `ublue-nvidia-flatpak-runtime-sync`: both `check` (exit 0 = needs sync, exit 1 = already synced) and `sync` (installs GL extension + updates all system flatpaks) branches are consistent
- [ ] `golang-github-nvidia-container-toolkit` exclusion in bluefin build script is still present
- [ ] `TimeoutStartSec` in `ublue-nvidia-flatpak-runtime-sync.service` is >= 900 (GL install + full flatpak update)
- [ ] `just check` and `pre-commit run --all-files` pass clean
