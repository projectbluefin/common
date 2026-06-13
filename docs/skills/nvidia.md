# NVIDIA GPU Support — Agent Skill

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
| `projectbluefin/bluefin-lts` | CentOS Stream 10 | `ublue-os/akmods-nvidia-open` OCI | ✅ (pre-existing, GDX) | ✅ `system_files_overrides/gdx/…/80-nvidia-container-toolkit.preset` |
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
  `org.freedesktop.Platform.GL.nvidia-<version>` Flatpak runtime on first boot. Needed for
  Flatpak apps to use the GPU. Triggered by `ublue-nvidia-flatpak-runtime-sync.service`.
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

### `projectbluefin/bluefin-lts` (GDX variant only)

- `build_scripts/overrides/gdx/20-nvidia.sh` — nvidia install script for the GDX flavor
- `system_files_overrides/gdx/usr/lib/systemd/system-preset/80-nvidia-container-toolkit.preset`

The LTS build uses an override directory system. `build.sh` calls `run_buildscripts_for gdx`
(runs `build_scripts/overrides/gdx/*.sh`) and `copy_systemfiles_for gdx` (copies
`system_files_overrides/gdx/` to `/`). Nvidia GDX changes go in those two locations.

The LTS build installs the *full* `nvidia-container-toolkit` package (not `-base`) from the
`fedora-nvidia` repo that the akmods bundle enables. This is pre-existing behavior; don't
change the package selection without testing the GDX build.

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

## `ujust aimode` — NVIDIA AI Workspaces control panel

### Architecture decision

`ujust aimode` is **one control panel**, not a collection of commands. It presents a single
`gum filter` menu of all available NGC stacks and deploys the selected one as Podman Quadlets.
Do not add separate `ujust ngc-login`, `ujust aimode-stop`, etc. commands — everything lives
inside `ujust aimode` as contextual sub-menus.

All AI tooling runs **entirely from NVIDIA's containers**. The host provides only:
- The driver (already in the NVIDIA image via akmods)
- `nvidia-container-toolkit-base` (already installed, CDI already live)

**No additional RPMs.** Never install RPMs for AI workloads on Bluefin. The NGC containers
carry their own complete CUDA/cuDNN/framework stack. Do not suggest RPMs for this feature.

### Stack catalog

Stacks live in `system_files/nvidia/usr/share/ublue-os/nvidia-stacks/<stack-key>/`:
- `stack.env` — bash-sourceable metadata (name, icon, description, VRAM, ports, etc.)
- `<stack-key>.container` — Podman Quadlet unit template (uses `${NGC_MONTH}` placeholder)
- `<stack-key>-network.network` — isolated Podman network per stack
- `ngc-month` (top-level file) — current NGC release train (e.g. `25.06`), updated by Renovate

At deploy time, `ujust aimode` runs `envsubst '${NGC_MONTH}'` on the quadlet templates and
writes results to `~/.config/containers/systemd/`. Then `systemctl --user daemon-reload`.

### Correct quadlet directives for NGC containers

```ini
[Container]
AddDevice=nvidia.com/gpu=all
PodmanArgs=--security-opt=label=disable
PodmanArgs=--ipc=host
Ulimit=memlock=-1:-1
Ulimit=stack=67108864:67108864
```

Do NOT use `Device=nvidia.com/gpu=all` (that is a different directive). `AddDevice=` is correct.
`--security-opt=label=disable` is required for CDI — SELinux labels on `/dev/nvidia*` conflict
with the container label. This is documented and expected.

### NGC containers used

| Stack key | Image | Notes |
|---|---|---|
| `pytorch-lab` | `nvcr.io/nvidia/pytorch:${NGC_MONTH}-py3` | Runs JupyterLab on port 8888 |
| `tensorflow-lab` | `nvcr.io/nvidia/tensorflow:${NGC_MONTH}-tf2-py3` | Runs JupyterLab on port 8888 |
| `rapids-ds` | `nvcr.io/nvidian/rapidsai/rapids:${NGC_MONTH}` | RAPIDS + JupyterLab, port 8888 |
| `triton-serving` | `nvcr.io/nvidia/tritonserver:${NGC_MONTH}-py3` | HTTP 8000 / gRPC 8001 / metrics 8002 |
| `nemo-training` | `nvcr.io/nvidia/nemo:${NGC_MONTH}` | JupyterLab on port 8888 |
| `nim-llama3` | `nvcr.io/nim/meta/llama-3.1-8b-instruct:latest` | OpenAI API on port 8000, needs NGC key |
| `nim-sdxl` | `nvcr.io/nim/stabilityai/stable-diffusion-xl:latest` | Image gen API, needs NGC key |

Note: RAPIDS uses `nvidian` (not `nvidia`) in the org path.

### NGC auth for NIM containers

NIM containers require an NGC API key. The key is stored as a Podman secret (not in
env files or quadlet templates):

```bash
printf '%s' "${NGC_KEY}" | podman secret create ngc-api-key -
podman login nvcr.io --username '$oauthtoken' --password "${NGC_KEY}"
```

The NIM quadlet unit references the secret:
```ini
Secret=ngc-api-key,type=env,target=NGC_API_KEY
```

Free NGC API key: https://build.nvidia.com/

### Ubuntu / DGX gap analysis — key findings

Researched 2026-06. The only Ubuntu-specific component in NVIDIA's AI stack is
**NVIDIA AI Workbench** (a GUI project manager, `.deb` only, no RPM/Flatpak).

Everything else — CUDA, NIM, NGC containers, nvidia-container-toolkit, CDI — is
fully distro-agnostic. NIM containers only require `nvidia-container-toolkit` on host.

Bluefin **advantages** over DGX OS / Ubuntu:
- Immutable host prevents `apt upgrade` breaking CUDA ABI (a common DGX pain point)
- CUDA lives in containers, not the host — no version conflicts across projects
- Quadlet units are git-versionable, diff-able, auditable vs Workbench's opaque `.project`
- `bootc` atomic updates vs separate apt/CUDA/driver/Workbench update paths

### DGX Spark (GB10 Grace Blackwell) notes

The DGX Spark is **ARM64 (`aarch64`)** — NVIDIA Grace CPU + Blackwell GPU on NVLink-C2C.

- Running Bluefin *on* a Spark is **blocked** by kernel device-tree patches not upstream yet.
  This is an upstream kernel blocker, not a Bluefin architectural issue. Track separately.
- Most NGC containers ship ARM64 layers in their multi-arch manifests already.
- Unified 128 GB LPDDR5X (CPU+GPU share memory over NVLink-C2C at 900 GB/s) means
  70B models fit natively, no quantization needed.
- Once DT patches upstream, Bluefin's immutable model is arguably better than DGX OS for
  Spark because it prevents the "update broke unified memory" failure mode.

File a tracking issue for ARM64/Spark support when `ublue-os/main` ships `aarch64` images.

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
