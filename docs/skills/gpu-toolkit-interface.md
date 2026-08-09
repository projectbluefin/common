---
name: gpu-toolkit-interface
version: "0.1"
last_updated: "2026-08-08"
id: gpu-toolkit-interface
one_line_purpose: Define the shared GPU vendor toolkit interface that all GPU support implementations must satisfy.
entry_point: docs/skills/gpu-toolkit-interface.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: [nvidia]
tags: [gpu, nvidia, amd, interface, architecture, cdi]
description: >-
  Vendor-agnostic GPU toolkit interface. Defines the six capabilities any
  GPU vendor integration must implement. NVIDIA is the reference
  implementation; AMD (common#277) must satisfy this interface before
  vendor-specific AMD code merges.
metadata:
  type: reference
---

# GPU Vendor Toolkit Interface — Architect Skill

**Status**: Interface definition (NVIDIA implements it; AMD must implement it before common#277 merges)
**Tracking**: common#963

## Why this document exists

The factory ships a complete NVIDIA GPU integration path. A feature request (common#277) asks
for AMD Container Toolkit support. If AMD is added by duplicating the NVIDIA pattern ad-hoc,
the result will be two parallel paths with:

- Duplicated kernel argument management
- Duplicated CDI/device spec generation
- Duplicated container runtime hook registration
- Duplicated Flatpak GPU extension management
- Duplicated akmods/driver lifecycle logic

This document defines a **vendor-agnostic interface** that NVIDIA currently satisfies and
that any future GPU vendor integration (AMD, Intel Arc) must also satisfy. Common owns
the interface; vendor-specific layers are specializations.

---

## The six-capability interface

Every GPU vendor toolkit integration in `common` / `bluefin` / `dakota` must provide:

### 1. Kernel argument management

| Requirement | Detail |
|-------------|--------|
| Declarative kargs | Vendor-specific kernel arguments expressed in `kargs.d/<vendor>.toml` under the image layer |
| No mutation at runtime | kargs must be baked at image build time, not mutated by scripts at runtime |
| No duplicates across layers | A karg defined in `common` must not be redefined in `bluefin` or `bluefin-lts` |

**NVIDIA implementation**: `kargs.d/00-nvidia.toml` in the downstream NVIDIA layers of
`bluefin-lts` and `dakota`. `common` itself carries no NVIDIA kargs; those repos are the
reference implementations for this capability.

**AMD gap**: ROCm does not require special kargs for standard consumer cards, but the pattern must be defined even if empty.

### 2. Container Device Interface (CDI) spec generation

| Requirement | Detail |
|-------------|--------|
| CDI-first | GPU container access uses CDI, not legacy OCI hooks |
| Runtime-generated spec | The CDI spec lives on tmpfs; a systemd service regenerates it on boot |
| Path watcher | A path unit triggers regen when the driver or toolkit binary changes |
| Preset | An 80-series preset enables the service and path units at first-boot |

**NVIDIA implementation** (downstream — these files live in the NVIDIA layers of
`bluefin-lts` and `dakota`, not in `common`):
- `nvidia-cdi-refresh.service` + `nvidia-cdi-refresh.path`
- `80-nvidia-container-toolkit.preset`
- Spec written to `/var/run/cdi/nvidia.yaml`

**AMD gap**: `amd-container-toolkit` (ROCm CTK) uses a similar CDI flow via `amdgpu-ctk cdi generate`. An `amd-cdi-refresh.service` + path unit + 80-series preset must be defined before AMD merges.

### 3. Container runtime toolkit (vendor tool)

| Requirement | Detail |
|-------------|--------|
| Minimal install | Only the base toolkit binary (CDI + device spec tool) — not the legacy OCI hook runtime |
| No legacy hook files | Do not install `/usr/share/containers/oci/hooks.d/oci-*-hook.json` |
| Rootless config | Run the toolkit config command to disable cgroup device delegation requirement |

**NVIDIA implementation**:
- `nvidia-container-toolkit-base` (NOT the full `nvidia-container-toolkit` package)
- `nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place`

**AMD implementation target**:
- `amdgpu-ctk` or equivalent base package from the ROCm repos
- Equivalent rootless config if needed by the AMD runtime

### 4. Flatpak GPU extension management

| Requirement | Detail |
|-------------|--------|
| Driver-version-matched extension | A service selects and installs the correct GL extension for the installed driver version |
| Non-blocking update | The service runs non-interactively and includes a generous timeout |
| Idempotent | Safe to run on every boot even when the extension is already at the correct version |

**NVIDIA implementation**:
- `ublue-nvidia-flatpak-runtime-sync` script in `system_files/nvidia/usr/libexec/`
- Installs `org.freedesktop.Platform.GL.nvidia-<version>` and runs `flatpak update --system --noninteractive`
- `TimeoutStartSec=900` in the service unit

**AMD gap**: AMD GPU Flatpak GL extension (`org.freedesktop.Platform.GL.default` or Mesa-based) is typically handled by the base Mesa stack, but the service pattern must be evaluated for AMD DX12/VK extension variants.

### 5. First-boot hook registration

| Requirement | Detail |
|-------------|--------|
| Hook type | `check` + `sync` hook pair in `usr/share/ublue-os/system-setup.hooks.d/` |
| `check` exit contract | Exit 0 = action needed; exit non-zero = already done |
| Idempotent `sync` | Safe to run more than once |

**NVIDIA implementation**: The `ublue-nvidia-flatpak-runtime-sync` script is triggered by `ublue-nvidia-flatpak-runtime-sync.service`, which is enabled by the 80-series preset. See `docs/skills/oem-hardware-hooks.md`.

**AMD implementation target**: AMD-specific first-boot hook if any GPU-version-matched runtime sync is needed.

### 6. SELinux policy (future — not blocking)

| Requirement | Detail |
|-------------|--------|
| Current state | CDI requires `--security-opt=label=disable`; no vendor-specific policy |
| Target | Proper SELinux policy module for `/dev/<vendor>*` CDI device nodes |

This is a known gap for all vendors. It is NOT a gating requirement for AMD merge but must be tracked.

---

## Directory layout convention

```
system_files/
  shared/              # Vendor-neutral files (applies to all variants)
  bluefin/             # Bluefin-specific (non-GPU)
  nvidia/              # NVIDIA vendor layer in common (flatpak runtime sync only)
    usr/
      lib/systemd/system/         # ublue-nvidia-flatpak-runtime-sync.service
      libexec/                    # ublue-nvidia-flatpak-runtime-sync
  amd/                 # AMD vendor layer — CREATE THIS DIRECTORY when implementing
    usr/
      lib/systemd/system/         # amd flatpak sync service (if needed)
      lib/systemd/system-preset/  # 80-amd-container-toolkit.preset
      libexec/                    # amd-flatpak-runtime-sync (if needed)
```

Note: the full NVIDIA reference implementation spans repos. `common`'s
`system_files/nvidia/` carries only the Flatpak runtime sync; the CDI refresh
units, `80-nvidia-container-toolkit.preset`, and NVIDIA kargs live in the
downstream NVIDIA layers of `bluefin-lts` and `dakota`. AMD should follow the
same split: vendor-neutral pieces in `common`, boot/CDI wiring downstream.

---

## Gating: what AMD must satisfy before common#277 merges

Use this checklist when reviewing any AMD GPU toolkit PR:

- [ ] `kargs.d/` entry in the vendor's downstream layer (or explicit documentation that no kargs are needed)
- [ ] `amd-cdi-refresh.service` and `amd-cdi-refresh.path` present in the downstream AMD layer
- [ ] `80-amd-container-toolkit.preset` enables the CDI units
- [ ] Base toolkit package only (no legacy OCI hook files)
- [ ] Rootless CDI config applied if required by the AMD runtime
- [ ] Flatpak GL extension management evaluated and either implemented or documented as not required
- [ ] First-boot hook pair if needed
- [ ] `system_files/amd/README.md` documents the layer (mirrors `system_files/nvidia/README.md`)
- [ ] CI build confirmed not to break non-AMD variants (the `amd/` layer must only apply to AMD image variants)
- [ ] This skill file updated with the AMD implementation column

---

## Adding a third vendor (Intel Arc, etc.)

The same six-capability interface applies. Any new vendor layer follows the same directory
convention and must satisfy the same checklist before merging. The interface is the gate.
