# NVIDIA — NGC Containers and Version Updates

Part of [nvidia](../SKILL.md) — NGC container ecosystem; key containers table; distrobox path; updating driver or toolkit versions.

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
