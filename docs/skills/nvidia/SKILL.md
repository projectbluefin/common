---
name: nvidia
version: "1.2"
last_updated: "2026-09-15"
id: nvidia
one_line_purpose: Maintain NVIDIA GPU support architecture and update procedures.
entry_point: docs/skills/nvidia/SKILL.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [nvidia, gpu, drivers, akmods]
description: >-
  NVIDIA GPU support architecture and update procedures. Use when editing
  nvidia files in system_files/nvidia/, bluefin scripts, or dakota elements.
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

---

## The three repos and their nvidia stacks

| Repo | Base OS | Driver source | NCT installed | CDI preset |
|---|---|---|---|---|
| `projectbluefin/common` | shared overlay | — | — | ❌ none — see "`system_files/nvidia/` ships to nobody" below |
| `projectbluefin/bluefin` | Fedora | `ublue-os/akmods-nvidia-open` OCI | ✅ (build script) | ❌ none in either repo |
| `projectbluefin/bluefin-lts` | CentOS Stream 10 | `ublue-os/akmods-nvidia-open` OCI | ✅ (nvidia build overlay) | ✅ `system_files_overrides/nvidia/…/80-nvidia-container-toolkit.preset` |
| `projectbluefin/dakota` | GNOME OS (BST) | `.run` installer, open kmod | ✅ (built from source) | ✅ `elements/bluefin-nvidia/nvidia-container-toolkit-preset.bst` |

**dakota is the reference implementation.** When in doubt about the correct approach for
nvidia-related changes, read `elements/bluefin-nvidia/` in dakota first.

### `system_files/nvidia/` ships to nobody

The ctx stage of this repo's `Containerfile` publishes `/system_files/nvidia`, but **no
consumer copies it**: in `projectbluefin/bluefin`, `projectbluefin/bluefin-lts` and
`projectbluefin/utah`, every `COPY --from=common /system_files/...` line in the
`Containerfile` names `/system_files/shared` or `/system_files/bluefin` — none names
`/system_files/nvidia`. Verify with
`grep -n 'COPY --from=common /system_files' Containerfile` in each repo rather than by line
number; those line numbers drift.
Nothing in the org enables `ublue-nvidia-flatpak-runtime-sync.service`, and this repo ships
no preset for it. Editing `system_files/nvidia/` therefore changes no image today.

`80-nvidia-container-toolkit.preset` has **never existed** in this repo
(`git log --all -- system_files/nvidia/usr/lib/systemd/system-preset` is empty), so bluefin
does not inherit a CDI preset from here either. Tracked in common#1124 — do not treat
`system_files/nvidia/` as a live delivery path until that issue is resolved.

---

## CDI is the architecture — not OCI hooks

Container GPU access uses **CDI (Container Device Interface)**, not the legacy nvidia OCI hook.

### How CDI works on bluefin

1. `nvidia-container-toolkit-base` ships two binaries: `nvidia-ctk` and `nvidia-cdi-hook`
2. `nvidia-cdi-refresh.service` runs `nvidia-ctk cdi generate` at boot → writes `/var/run/cdi/nvidia.yaml`
3. `nvidia-cdi-refresh.path` watches `/lib/modules/*/modules.dep` and `/usr/bin/nvidia-ctk`
4. The systemd preset (`80-nvidia-container-toolkit.preset`) enables both units at first boot
5. Podman v4.1.0+: `podman run --device nvidia.com/gpu=all --security-opt=label=disable ...`

The CDI spec lives at `/var/run/cdi/nvidia.yaml` — ephemeral tmpfs, regenerated on every boot. Do not bake it into the image.

### What NOT to install

Do **not** install `nvidia-container-runtime`, `libnvidia-container1`, `libnvidia-container-tools`, or `nvidia-container-toolkit` (full). Use the `-base` variant only. See [`references/architecture.md`](references/architecture.md) for full detail.

---

## Constraints

- **Turing+ only (GTX 16xx, RTX 20xx+)** for open kernel modules.
- **CDI spec is runtime-only** — lives on tmpfs, regenerated on every boot.
- **No cross-repo writes to `ublue-os/*`** — report to a human who will file upstream manually.
- **`golang-github-nvidia-container-toolkit` exclusion** in bluefin is intentional — do not remove it.

---

## Red Flags

- Removing the `80-nvidia-container-toolkit.preset` CDI preset
- Removing the `golang-github-nvidia-container-toolkit` exclusion from the bluefin build script
- Installing `nvidia-container-runtime` or the full `nvidia-container-toolkit` package
- `TimeoutStartSec` in `ublue-nvidia-flatpak-runtime-sync.service` drops below 900

---

## Verification

Before closing any nvidia-related PR:

- [ ] Changes to `system_files/nvidia/` tested to not break non-nvidia builds (shared layer affects all variants)
- [ ] No `ublue-os/*` repos were written to
- [ ] CDI preset not accidentally removed — `80-nvidia-container-toolkit.preset` still enables `nvidia-cdi-refresh.{path,service}`
- [ ] If editing `ublue-nvidia-flatpak-runtime-sync`: both `check` and `sync` branches are consistent
- [ ] `golang-github-nvidia-container-toolkit` exclusion in bluefin build script is still present
- [ ] `TimeoutStartSec` in `ublue-nvidia-flatpak-runtime-sync.service` is >= 900
- [ ] `just check` and `pre-commit run --all-files` pass clean

---

## References

| Reference | Description |
|---|---|
| [`references/architecture.md`](references/architecture.md) | CDI architecture detail; what not to install; rootless config; SELinux notes; per-repo code locations (common, bluefin, bluefin-lts, dakota) |
| [`references/ngc-containers.md`](references/ngc-containers.md) | NGC container ecosystem; key containers table; distrobox path; updating driver or toolkit versions |
