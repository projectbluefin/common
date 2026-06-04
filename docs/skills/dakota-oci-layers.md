---
name: dakota-oci-layers
description: Use when understanding how packages flow into the final OCI image in projectbluefin/dakota, when modifying layer assembly, or when debugging why files appear or are missing from the built image
---

# OCI Layer Composition (dakota)

## Powerlevel

- **Level:** 1


## Overview

The Bluefin OCI image is assembled through a chain of BuildStream elements in `elements/oci/` and `elements/oci/layers/`. Each element kind has a specific role: **stack** elements aggregate dependencies, **compose** elements filter artifacts by split domain, **collect_initial_scripts** collects first-boot scripts, and **script** elements perform final OCI assembly.

Load with: `cat ~/src/skills/dakota-oci-layers/SKILL.md`

## When to Use

- You need to understand how a new package gets included in the OCI image
- You're debugging why a file is present or missing from the built image
- You're adding a new filesystem layer or modifying layer composition
- You need to understand split domains (devel, debug, extra) and what gets excluded
- You're modifying OCI metadata (labels, annotations, os-release)

## When NOT to Use

- Adding a new package to the image (just add to `deps.bst`) → use `dakota-add-package` for the full workflow
- Writing or reviewing `.bst` element files → use `dakota-buildstream` for the reference tables
- Diagnosing element build failures → use `dakota-debugging`

## The Layer Chain

Every package follows this path from element to OCI image:

```
bluefin/my-package.bst
        |
        v
bluefin/deps.bst                    (kind: stack -- aggregates ALL bluefin packages)
        |
        v
oci/layers/bluefin-stack.bst         (kind: stack -- merges bluefin + gnomeos dependencies)
        |
        v
oci/layers/bluefin-runtime.bst       (kind: compose -- EXCLUDES devel, debug, static-blocklist)
        |
        v
oci/layers/bluefin.bst              (kind: compose -- FURTHER EXCLUDES extra, debug, static-blocklist)
        |
        v
oci/bluefin.bst                     (kind: script -- OCI assembly with build-oci heredoc)
```

### Element Kinds in the Chain

| Element | Kind | Purpose |
|---|---|---|
| `bluefin/deps.bst` | `stack` | Master package list. Add your package here as a dependency. |
| `oci/layers/bluefin-stack.bst` | `stack` | Merges `bluefin/deps.bst` with `gnome-build-meta.bst:oci/layers/gnomeos-stack.bst` |
| `oci/layers/bluefin-runtime.bst` | `compose` | Filters out `devel`, `debug`, `static-blocklist` split domains |
| `oci/layers/bluefin.bst` | `compose` | Filters out `extra`, `debug`, `static-blocklist` (final layer content) |
| `oci/layers/bluefin-init-scripts.bst` | `collect_initial_scripts` | Collects first-boot scripts at `/initial_scripts` |
| `oci/bluefin.bst` | `script` | Final OCI assembly: `prepare-image.sh`, `systemd-sysusers`, `glib-compile-schemas`, `dconf update`, `ldconfig -r /layer -f /layer/etc/ld.so.conf`, `build-oci` |

### Two-Stage Compose Filtering

Compose elements filter artifacts by **split domains** (defined in `project.conf` or inherited from junctions). The two-stage compose ensures:

1. **`bluefin-runtime.bst`**: Excludes `devel` (headers, pkg-config, static libs) + `debug` + `static-blocklist`. This removes build-time-only artifacts.
2. **`bluefin.bst`**: Further excludes `extra` + `debug` + `static-blocklist`. This removes documentation, large optional data, etc.

If your package installs files that land in an excluded split domain, they will NOT appear in the final image. Common splits:
- **devel**: `/usr/include/`, `/usr/lib/pkgconfig/`, `*.a` static libraries
- **debug**: `/usr/lib/debug/` debug symbols
- **extra**: `/usr/share/doc/`, `/usr/share/man/`, large optional files

### `gcc.bst` in the Final Compose

`oci/layers/bluefin.bst` has an unusual build-dep on `freedesktop-sdk.bst:components/gcc.bst`. This pulls GCC's runtime libraries (libstdc++, libgcc_s) into the final image -- NOT the compiler itself. The `compose` filter excludes devel artifacts, so only the shared libraries survive.

## Parent Layer Hierarchy

The Bluefin image is layered on top of GNOME OS:

```
freedesktop-sdk: oci/platform.bst              (base freedesktop runtime)
        |
        v
gnome-build-meta: oci/platform.bst             (GNOME platform)
        |
        v
gnome-build-meta: oci/gnomeos.bst              (GNOME OS layer -- kind: script, upstream)
        |
        v
oci/bluefin.bst                                (Bluefin layer -- kind: script)
```

### Junction Overrides

Several elements in `elements/oci/` are **local overrides** of upstream gnome-build-meta elements. The `elements/gnome-build-meta.bst` junction declares these overrides in `config.overrides`:

```yaml
config:
  overrides:
    oci/os-release.bst: oci/os-release.bst
    core/meta-gnome-core-apps.bst: core/meta-gnome-core-apps.bst
    gnomeos-deps/plymouth-gnome-theme.bst: bluefin/plymouth-bluefin-theme.bst
```

## OCI Assembly Script (oci/bluefin.bst)

The final `kind: script` element does this:

- Mounts parent GNOME OS image at `/parent` and Bluefin layer at `/layer`
- Uses `LD_PRELOAD` with **`fakecap`** to emulate filesystem capabilities in the bubblewrap sandbox
- Runs `prepare-image.sh` to set up the ostree/bootc-compatible sysroot
- Runs `glib-compile-schemas` once on the full merged layer (individual package elements do NOT do this)
- Merges `/usr/etc` into `/etc` (bootc requirement -- no `/usr/etc` in final images)
- Runs `build-oci` heredoc to produce the OCI artifact

## OCI Labels and Metadata

```yaml
config:
  Labels:
    'com.github.containers.toolbox': 'true'
    'containers.bootc': '1'
    'org.opencontainers.image.source': 'https://github.com/projectbluefin/dakota'
index-annotations:
  'org.opencontainers.image.ref.name': 'ghcr.io/projectbluefin/dakota:latest'
```

## First-Boot Scripts (collect_initial_scripts)

Elements can declare first-boot scripts via `public.initial-script`:

```yaml
# In a package element:
public:
  initial-script:
    script: |
      #!/bin/bash
      sysroot="${1}"
      chmod 4755 "${sysroot}/usr/bin/something"
```

The `collect_initial_scripts` element walks the dependency tree and collects all `public.initial-script` declarations into `/initial_scripts/`. These scripts run during OCI assembly via `prepare-image.sh --initscripts /initial_scripts`.

Use cases: setting capabilities, creating system users, adjusting file permissions -- things that can't be done at build time in the sandbox.

## os-release Element

`oci/os-release.bst` (`kind: manual`) generates `/usr/lib/os-release` and `/usr/share/ublue-os/image-info.json`. Key environment variables:

| Variable | Value |
|---|---|
| `IMAGE_NAME` | `dakota` |
| `IMAGE_VENDOR` | `projectbluefin` |
| `IMAGE_PRETTY_NAME` | `Bluefin` |
| `ID` | `bluefin-dakota` |
| `CODE_NAME` | `Dakotaraptor` |

## Adding a Package to the Image

The only file you need to modify to add a package is **`elements/bluefin/deps.bst`**:

```yaml
# In elements/bluefin/deps.bst:
depends:
  - bluefin/my-new-package.bst
```

The rest of the chain picks it up automatically.

### When You DO Need to Modify the OCI Layer

Rare cases where you'd touch `elements/oci/`:
- **Changing OCI labels/annotations**: Edit `oci/bluefin.bst`
- **Changing os-release metadata**: Edit `oci/os-release.bst` environment variables
- **Adding a new split domain exclusion**: Edit the `compose` elements' `config.exclude` lists
- **Changing the parent image**: Edit `oci/bluefin.bst` build-depends

## Variant Images (e.g. dakota-nvidia)

To produce a parallel OCI image that layers extra content on top of the base image, create a new parallel layer chain. The pattern is:

1. **New compose layer** (`elements/oci/layers/bluefin-<variant>.bst`, `kind: compose`) — `build-depends` on the package filter elements (e.g. `gnome-build-meta.bst:gnomeos-deps/nvidia-drivers-libs.bst`). This merges the variant's artifacts into a staging dir.
2. **New init-scripts element** (`elements/oci/layers/bluefin-<variant>-init-scripts.bst`, `kind: collect_initial_scripts`) if any package in the variant declares a `public.initial-script`. Depends on the compose layer.
3. **New OCI script** (`elements/oci/bluefin-<variant>.bst`, `kind: script`) — mirrors `oci/bluefin.bst` but:
   - Parent is `oci/bluefin.bst` (the full base image), not `gnome-build-meta.bst:oci/gnomeos/image.bst`
   - Layer is `oci/layers/bluefin-<variant>.bst`
   - Init scripts element is `oci/layers/bluefin-<variant>-init-scripts.bst`
   - New unique `sysroot-seed` UUID
   - **Only include `glib-compile-schemas` if the variant adds GLib schemas** — do not copy it blindly from `bluefin.bst`
   - **Only include `dconf update` if the variant adds dconf profiles** — same rule
   - Always include the `/usr/etc` → `/etc` fixup
   - **Always include `ldconfig -r /layer -f /layer/etc/ld.so.conf` after `dconf update` and before `build-oci`** — see ldconfig rule below

### ldconfig is load-bearing in every OCI script element

`ldconfig -r /layer -f /layer/etc/ld.so.conf` must appear in every `oci/*.bst` script element, after all
package installs and before `build-oci`. It writes `/etc/ld.so.cache` into the
image sysroot. Without it, any library SO version bump (Mesa `libgallium`,
Pipewire, etc.) leaves the deployed system with a stale linker cache after
`bootc switch`, causing silent `dlopen()` failures on first boot.

If you are adding a new post-install step, insert it **before** `ldconfig -r
/layer` so the final cache reflects the fully-installed state.

> ⚠️ **`kind: stack` produces no filesystem payload.** It is a dependency aggregator only. A layer element that will be staged at `/layer` in the OCI script MUST be `kind: compose`. Using `kind: stack` silently produces an empty `/layer` — the image builds successfully but contains no variant content.

## Common Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Adding package to compose/script instead of deps.bst | Package not included or breaks layer chain | Add to `bluefin/deps.bst` -- it flows through automatically |
| Running `glib-compile-schemas` in a package element | Schemas compiled against incomplete set | Don't -- it runs once in `oci/bluefin.bst` on the full merged layer |
| Running `glib-compile-schemas` in a variant OCI script with no schemas | Error or empty `gschemas.compiled` clobbers parent | Only run if the variant actually installs schemas |
| Expecting `/usr/etc` in the final image | Files missing from `/etc` | Image merges `/usr/etc` into `/etc` at assembly time |
| Forgetting overlap-whitelist when replacing upstream files | Build fails with file overlap error | Add `public.bst.overlap-whitelist` in your package element |
| Installing files into devel/debug split domains | Files excluded by compose filters | Install to runtime paths (`/usr/bin`, `/usr/lib`, `/usr/share`) |
| Using `kind: stack` for a layer element | Empty `/layer` in OCI — no content in image | Use `kind: compose` for any element staged as `/layer` |

## Real Files

| File | Kind | Purpose |
|---|---|---|
| `elements/bluefin/deps.bst` | stack | Master package list -- add packages here |
| `elements/oci/layers/bluefin-stack.bst` | stack | Merges bluefin + gnomeos stacks |
| `elements/oci/layers/bluefin-runtime.bst` | compose | First filter (excludes devel) |
| `elements/oci/layers/bluefin.bst` | compose | Second filter (excludes extra) |
| `elements/oci/layers/bluefin-init-scripts.bst` | collect_initial_scripts | First-boot scripts |
| `elements/oci/bluefin.bst` | script | Final OCI assembly |
| `elements/oci/os-release.bst` | manual | OS release metadata |
