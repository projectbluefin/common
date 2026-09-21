# NVIDIA — Architecture and Per-Repo Code Locations

Part of [nvidia](../SKILL.md) — CDI architecture detail, what not to install, rootless config, SELinux notes, and per-repo code locations.

---

## CDI is the architecture — not OCI hooks

Container GPU access uses **CDI (Container Device Interface)**, not the legacy nvidia OCI hook. This is the correct approach for bootc/immutable/rootless systems.

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

**Not currently delivered.** The ctx stage publishes `/system_files/nvidia`, but every
consumer copies `/system_files/shared` and `/system_files/bluefin` only — in bluefin,
bluefin-lts and utah, `grep -n 'COPY --from=common /system_files' Containerfile` returns
only `shared` and `bluefin` lines, never `nvidia` (cited by content because the line
numbers in those repos drift). No
preset here and no `systemctl enable` anywhere in the org references
`ublue-nvidia-flatpak-runtime-sync.service`, so neither the unit nor the helper is present in
a built image. `tests/test_nvidia_flatpak_sync.bats` asserts against the files on disk and
passes regardless. Changes here reach **no** image until common#1124 is resolved.

There is no `system_files/nvidia/usr/lib/systemd/system-preset/80-nvidia-container-toolkit.preset`
in this repo and there never has been; CDI auto-generation is enabled per-consumer
(bluefin-lts `system_files_overrides/gdx/…`, dakota `elements/bluefin-nvidia/…`) and the
Fedora bluefin variant has no such preset in either repo.

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

## SELinux and CDI

Running NGC containers requires `--security-opt=label=disable` with Podman + CDI.
This is documented in NVIDIA's own CDI guide and is expected behavior — SELinux labels
on `/dev/nvidia*` and the driver lib mounts conflict with the default container label.

A proper SELinux policy module for nvidia CDI devices is a future improvement.
