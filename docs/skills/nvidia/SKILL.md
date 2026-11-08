---
name: nvidia
version: "1.4"
last_updated: "2026-09-26"
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
  bluefin scripts, or dakota elements.
metadata:
  type: reference
---

# NVIDIA GPU Support — Agent Skill

## When to Use

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
| `projectbluefin/common` | shared overlay | — | — | ❌ none |
| `projectbluefin/bluefin` | Fedora | `ublue-os/akmods-nvidia-open` OCI | ✅ (build script) | ❌ none in either repo |
| `projectbluefin/bluefin-lts` | CentOS Stream 10 | `ublue-os/akmods-nvidia-open` OCI | ✅ (nvidia build overlay) | ✅ `system_files_overrides/nvidia/…/80-nvidia-container-toolkit.preset` |
| `projectbluefin/dakota` | GNOME OS (BST) | `.run` installer, open kmod | ✅ (built from source) | ✅ `elements/bluefin-nvidia/nvidia-container-toolkit-preset.bst` |

**dakota is the reference implementation.** When in doubt about the correct approach for
nvidia-related changes, read `elements/bluefin-nvidia/` in dakota first.

### The suspend quirk lives in `shared/`

`system_files/shared/usr/lib/modprobe.d/zz-nvidia-suspend.conf` pins

- `NVreg_UseKernelSuspendNotifiers=1` — without notifiers (or the
  `nvidia-suspend.service` procfs handshake), the driver vetoes system PM
  (`nv_pmops_suspend` → `NV_ERR_NOT_SUPPORTED`), systemd-suspend aborts, and
  the machine wakes seconds after sleep starts (common#803, same failure class
  as dakota#1118).
- `NVreg_TemporaryFilePath=/var/lib/systemd/sleep` — the default `/tmp` is
  tmpfs; a failed VRAM save there aborts suspend through the notifier path too.
  It must not be `/var/tmp`: with notifiers the save file is opened from
  `systemd-sleep` (`systemd_sleep_t`), which Fedora's SELinux policy denies on
  `tmp_t`, so VRAM is lost and the GPU crashes on resume (utah#492/#533,
  fedora-selinux/selinux-policy#3087). `/var/lib/systemd/sleep` is
  `systemd_sleep_var_lib_t`, which the policy already lets that domain manage.
  `usr/lib/tmpfiles.d/nvidia-suspend.conf` creates the directory (systemd does
  not ship it); `tests/test_nvidia_suspend.bats` keeps the two in step.

Both options are inert on systems without the nvidia module and ignored as
unknown parameters by drivers that predate them. The `zz-` prefix keeps the
file sorted after the driver packages' `nvidia.conf` so these assignments win
duplicates. This repo ships no nvidia-only overlay (common#1124), so this quirk
must stay in `shared/`.

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

- Pointing `NVreg_TemporaryFilePath` at `/var/tmp`, `/tmp` or any other path `systemd_sleep_t` cannot write — the VRAM save is denied under enforcing SELinux and resume crashes the GPU (utah#533)
- Removing `system_files/shared/usr/lib/modprobe.d/zz-nvidia-suspend.conf` or either of its options — sleep regresses to the common#803 "wakes seconds after suspend" veto on images whose driver package does not pin them
- Removing the `80-nvidia-container-toolkit.preset` CDI preset
- Removing the `golang-github-nvidia-container-toolkit` exclusion from the bluefin build script
- Installing `nvidia-container-runtime` or the full `nvidia-container-toolkit` package

---

## Verification

Before closing any nvidia-related PR:

- [ ] `zz-nvidia-suspend.conf` still carries `NVreg_UseKernelSuspendNotifiers=1` and `NVreg_TemporaryFilePath=/var/lib/systemd/sleep` (common#803, utah#533), and `tmpfiles.d/nvidia-suspend.conf` still creates that directory
- [ ] No `ublue-os/*` repos were written to
- [ ] CDI preset not accidentally removed — `80-nvidia-container-toolkit.preset` still enables `nvidia-cdi-refresh.{path,service}`
- [ ] `golang-github-nvidia-container-toolkit` exclusion in bluefin build script is still present
- [ ] `just check` and `pre-commit run --all-files` pass clean

---

## References

| Reference | Description |
|---|---|
| [`references/architecture.md`](references/architecture.md) | CDI architecture detail; what not to install; rootless config; SELinux notes; per-repo code locations (common, bluefin, bluefin-lts, dakota) |
| [`references/ngc-containers.md`](references/ngc-containers.md) | NGC container ecosystem; key containers table; distrobox path; updating driver or toolkit versions |
