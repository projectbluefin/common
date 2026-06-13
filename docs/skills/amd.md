# AMD GPU Support — Agent Skill

## What this covers

The AMD AI Workspaces stack ships ROCm-accelerated inference and dev containers as Podman
Quadlets managed by `ujust aimode-amd`. This skill covers the device model, stack catalog,
per-stack quirks, Renovate version tracking, and how to add new stacks.

---

## Device model — `/dev/kfd` + `/dev/dri`

AMD uses in-tree kernel drivers (`amdgpu`), so no toolkit CDI layer is needed.
All GPU access goes through two devices:

| Device | Purpose |
|--------|---------|
| `/dev/kfd` | Kernel Fusion Driver — HSA compute interface (required for ROCm) |
| `/dev/dri` | DRM render nodes (`card0`, `renderD128`, …) |

### Correct Quadlet directives for ROCm containers

```ini
[Container]
AddDevice=/dev/kfd
AddDevice=/dev/dri
PodmanArgs=--security-opt=label=disable
PodmanArgs=--group-add=video
```

`--security-opt=label=disable` is required for the same reason as NVIDIA: SELinux labels
on `/dev/kfd` and `/dev/dri` conflict with the default container label. This is documented
and expected on Fedora/bootc systems.

`--group-add=video` makes the container process a member of the `video` supplementary group,
which allows DRM render node access inside the container.

### Host render group requirement

Rootless Podman on Fedora requires the user to be in the `render` (and optionally `video`)
group to pass through GPU devices. The recipe checks this at startup:

```bash
sudo usermod -aG render,video $USER   # then log out and back in
```

This is a one-time setup on fresh Bluefin AMD installs. It is not automated because group
changes require a session restart — adding the user silently would confuse anyone who doesn't
understand why GPU access fails until re-login.

### vLLM extra flags

vLLM requires additional flags for multi-process tensor parallelism:

```ini
PodmanArgs=--security-opt=seccomp=unconfined
PodmanArgs=--ipc=host
AddCapability=SYS_PTRACE
```

`--ipc=host` is mandatory for vLLM shared memory across workers.
`SYS_PTRACE` is needed for some GPU management calls and profiling.
`seccomp=unconfined` is needed for numactl / memory mapping in HPC mode.

---

## Stack catalog

Stacks live in `system_files/amd/usr/share/ublue-os/amd-stacks/<stack-key>/`:

| Stack key | Image | Port | VRAM | Notes |
|-----------|-------|------|------|-------|
| `ollama` | `docker.io/ollama/ollama:rocm` | 11434 | 4 GB | Widest GPU support (RDNA2+); models via `ollama pull` |
| `lemonade` | `ghcr.io/lemonade-sdk/lemonade-server:v10.7.0` | 13305 | 4 GB | ROCm + Vulkan + Ryzen AI NPU; needs `config.json` |
| `vllm` | `docker.io/vllm/vllm-openai-rocm:latest` | 8000 | 16 GB | RDNA3+ / MI series; OpenAI API; HF token optional |
| `pytorch-lab` | `docker.io/rocm/pytorch:rocm${ROCM_VERSION}_…` | 8888 | 8 GB | JupyterLab workspace; version-pinned via `rocm-version` |

### GPU support matrix per stack

| GPU family | GFX target | Ollama | Lemonade | vLLM | PyTorch Lab |
|-----------|-----------|--------|---------|------|------------|
| RDNA4 (RX 9000) | gfx1200/gfx1201 | ✅ | ✅ | ✅ | ✅ |
| RDNA3 (RX 7000) | gfx1100/gfx1101 | ✅ | ✅ | ✅ | ✅ |
| Ryzen AI / Strix | gfx1151/gfx1150 | ✅ | ✅ (NPU) | ✅ | ✅ |
| RDNA2 (RX 6000) | gfx1030 | ✅ | ⚠️ Vulkan | ❌ | ✅ |
| Instinct MI300/MI250 | gfx942/gfx90a | ✅ | ✅ | ✅ | ✅ |
| Instinct MI100 | gfx908 | ⚠️ no rocBLAS | ❌ | ✅ | ✅ |

Ollama strips `gfx906` rocBLAS kernels from its image — MI50/Vega20 falls back to CPU.
Lemonade's ROCm backend requires RDNA3+ or Instinct; RDNA2 falls back to Vulkan automatically.

### Unsupported GPUs — HSA_OVERRIDE

Older GPUs (RX 5000 series, Vega 56/64) are not in the official ROCm support matrix
but can work with `HSA_OVERRIDE_GFX_VERSION`. Format: `x.y.z`

```bash
# RX 5700 XT (gfx1012) → target closest supported: gfx1010 = 10.1.0
podman run -e HSA_OVERRIDE_GFX_VERSION=10.1.0 ...

# RX 5600 XT (gfx1012) same override
# Vega 56 (gfx900) = 9.0.0
```

For Quadlet deployment, add `Environment=HSA_OVERRIDE_GFX_VERSION=x.y.z` to the `.container`
file before deploying. This is a manual step; the recipe does not auto-detect unsupported GPUs.

---

## Version tracking — `rocm-version` file

`amd-stacks/rocm-version` contains the ROCm version string (e.g., `7.2.4`). It is:

1. Read by `amd.just` at startup and exported as `$ROCM_VERSION`
2. Substituted into `.container` files via `envsubst '${ROCM_VERSION} ${VLLM_MODEL}'`
3. Used only by the PyTorch Lab image tag:
   `rocm/pytorch:rocm${ROCM_VERSION}_ubuntu24.04_py3.12_pytorch_release_2.10.0`

**Renovate**: Configure a regex extractor on `rocm-version` to track ROCm releases.
Other stacks (Ollama, Lemonade, vLLM) use floating or version-pinned tags directly in
their `.container` files — Renovate updates those in-place with standard image tracking.

Unlike NGC's monthly train, AMD stacks don't share a unified release cadence, so each
image tag is tracked independently.

---

## Lemonade — special deploy step

Lemonade requires a `config.json` to select the inference backend. The recipe creates it
on first deploy at `~/ai-workspaces/lemonade/config/config.json`:

```json
{"llamacpp": {"backend": "rocm"}}
```

The file persists across redeployments (only written if it doesn't exist). To switch to
Vulkan backend (for GPUs not supported by ROCm):

```bash
echo '{"llamacpp": {"backend": "vulkan"}}' \
  > ~/ai-workspaces/lemonade/config/config.json
ujust aimode-amd  # → Redeploy lemonade
```

Available backends: `rocm`, `vulkan`, `cuda`, `cpu`. For NPU: `{"flm": {"backend": "npu"}}`.

Lemonade downloads ROCm/Vulkan llamacpp binaries on first model load, not at container pull.
They are cached in `~/ai-workspaces/lemonade/llama/` and persist across container updates.
Expect a ~500 MB download on first use.

---

## vLLM — HuggingFace token injection

The recipe stores the HF token as a Podman secret at deploy time:

```bash
printf '%s' "${HF_TOKEN}" | podman secret create hf-token -
```

The secret is then injected into the quadlet at write time by appending:

```ini
Secret=hf-token,type=env,target=HF_TOKEN
```

This line is **not** in the template file — it is added by the recipe only when:
1. `STACK_REQUIRES_HF_AUTH=true` in `stack.env`
2. `podman secret exists hf-token` returns 0

This pattern avoids container startup failures when no secret exists. The default model
(`Qwen/Qwen2.5-7B-Instruct`) is fully open and does not require a token.

### Changing the default vLLM model

`VLLM_MODEL` is set in `vllm/stack.env` and exported before envsubst. To deploy a
different model without editing the stack file:

```bash
VLLM_MODEL="meta-llama/Llama-3.1-8B-Instruct" ujust aimode-amd
```

Or edit `stack.env` and redeploy.

---

## ujust aimode integration

`aimode-amd` is the AMD backend for the unified `ujust aimode` GPU autodetection flow.
The unified recipe (owned by the `ujust aimode` work stream) dispatches here when it
detects an AMD GPU via `/dev/kfd` presence. The recipe can also be called directly.

Do not add a separate `ujust aimode-amd-stop` or similar commands. All lifecycle
management (Start / Stop / Logs / Remove / Redeploy) lives inside `aimode-amd` as
contextual sub-menus, mirroring the NVIDIA `aimode` pattern.

---

## Adding new stacks

Drop a new directory under `amd-stacks/` with three files:

```
amd-stacks/<key>/
  stack.env         # STACK_ORDER, STACK_ICON, STACK_NAME, STACK_DESC, STACK_CATEGORY,
                    # STACK_VRAM_GB, STACK_DISK_GB, STACK_PORTS, STACK_REQUIRES_HF_AUTH
  <key>.container   # Quadlet unit — use AddDevice=/dev/kfd + /dev/dri, not CDI
  <key>-network.network  # [Network] NetworkName=<key>-net
```

The control panel auto-discovers the new stack on next run. No changes to `amd.just` needed.

**Stack checklist:**
- [ ] `AddDevice=/dev/kfd` and `AddDevice=/dev/dri` (not CDI)
- [ ] `PodmanArgs=--security-opt=label=disable` (SELinux)
- [ ] `PodmanArgs=--group-add=video` (render node group)
- [ ] Named volume under `%h/ai-workspaces/<key>/` for model/data persistence
- [ ] `Network=<key>-network.network` pointing to the companion `.network` file
- [ ] `STACK_ORDER` chosen to reflect UX priority (lower = shown first)

---

## No RPMs

All AI tooling runs entirely from containers. The host provides:
- The `amdgpu` driver (already in-tree, ships with all Fedora/Bluefin images)
- Podman (already installed on all Bluefin images)

**Never install ROCm RPMs, HIP packages, or any AI framework RPMs on the host.**
The containers carry their own complete ROCm stack.

---

## Constraints

- **vLLM ROCm** does not support RDNA2 (RX 6000) or older. Use Ollama or Lemonade for those.
- **Ollama ROCm** strips MI50 (gfx906) rocBLAS kernels — MI50 falls back to CPU.
- **Lemonade ROCm** backend requires RDNA3+ or Instinct; RDNA2 auto-falls-back to Vulkan.
- **`vllm/vllm-openai-rocm`** uses `latest` tag — Renovate should track it with digest pinning.
  The image is ~11 GB; a digest bump may trigger a large pull.
- **`/dev/kfd` is shared** across all GPU containers — multiple ROCm containers running
  simultaneously may contend for GPU resources. Only run one heavyweight stack at a time.
- **rootless `--ipc=host`** may need `--pid=host` in some podman rootless configurations.
  If vLLM fails with shared memory errors, check `podman info | grep ipcns`.
