---
name: dakota-add-package
description: Use when adding a new software package to the dakota/Bluefin BuildStream build, creating a new .bst element, or asking how to package something for the image
---

# Adding a Package (dakota)

## Powerlevel

- **Level:** 1


## Overview

Entry-point workflow for adding any software package to the Bluefin image.

Load with: `cat ~/src/skills/dakota-add-package/SKILL.md`

## Agent Quick-Start

```bash
# Binary (pre-built GitHub Release)
just scaffold-binary <name> <owner/repo>
# Rust/Cargo from source
just scaffold-rust <name> <owner/repo>
# GNOME Shell extension
just scaffold-gnome-ext <name> <owner/repo>
# Go: copy files/templates/git-tracked.bst manually
```

Each scaffold command creates `elements/bluefin/<name>.bst` from `files/templates/` and prints the exact next steps. Follow its output — do not continue until the printed checklist is complete.

**Template files:** `files/templates/binary.bst`, `rust.bst`, `gnome-ext.bst`, `git-tracked.bst`

## When to Use

- Adding a new software package to the Bluefin OCI image for the first time
- Creating a `.bst` element for any source type (binary, Rust, Go, Zig, GNOME extension, config)
- Setting up systemd services or presets for a new package
- Wiring an element into `deps.bst` and validating the full build

## When NOT to Use

- Removing a package from the image → use `dakota-remove-package` instead
- Updating an existing package's version → use `dakota-update-refs` instead
- Debugging a build failure in an existing element → use `dakota-debugging` instead
- Looking up BuildStream variable/kind reference only → use `dakota-buildstream` instead

## Choose Element Kind

| Source type | BuildStream kind | Sub-skill |
|---|---|---|
| Pre-built binary/tarball | `manual` + tar/remote source | `dakota-package-binaries` |
| Source with Meson build | `meson` | — |
| Source with Makefile | `make` | — |
| Source with autotools | `autotools` | — |
| Source with CMake | `cmake` | — |
| Rust/Cargo project | `make` + `cargo2` sources | `dakota-package-rust` |
| Go project | `make` or `manual` + GOPATH/go_module | `dakota-package-go` |
| Zig project | `manual` + offline cache | `dakota-package-zig` |
| GNOME Shell extension | `import`/`meson`/`make` + extension layout | `dakota-package-gnome-extensions` |
| Config files only | `import` | — |
| Dependency group | `stack` | — |

**Go projects:** `make` kind with vendored deps. Load `dakota-package-go`.

**Rust/Cargo projects:** `make` kind (not `cargo` kind) with `cargo2` sources. Load `dakota-package-rust`.

**Zig projects:** `manual` kind with `zig build` commands. Load `dakota-package-zig`.

**GNOME Shell extensions:** `import`/`meson`/`make` kind with GNOME Shell extension directory layout. Load `dakota-package-gnome-extensions`.

**Pre-built binaries:** Load `dakota-package-binaries` for multi-arch dispatch, `strip-binaries`, and source patterns.

## Workflow

1. **Create element** at `elements/bluefin/<name>.bst`
2. **Add to deps** — add `bluefin/<name>.bst` to the `depends:` list in `elements/bluefin/deps.bst`
3. **Add source alias** — if the download domain is new, add an alias to `include/aliases.yml` (file aliases for tarballs, git aliases for repos)
4. **Validate** — `just bst show bluefin/<name>.bst`
5. **Build element** — `just bst build bluefin/<name>.bst`
6. **Full image test** — `just build` or `just show-me-the-future`

Load `dakota-debugging` for build commands and troubleshooting.

## Systemd Service Installation

Services bundled with a package need three things:

| What | Where | Notes |
|---|---|---|
| Service file | `%{indep-libdir}/systemd/system/` (= `/usr/lib/systemd/system/`) | Patch `/usr/sbin` to `/usr/bin`; remove `EnvironmentFile=/etc/default/*` lines |
| Preset file | `%{indep-libdir}/systemd/system-preset/80-<name>.preset` | Content: `enable <service-name>.service` |
| Binaries | `%{bindir}` (= `/usr/bin`) | Never `/usr/sbin` — GNOME OS uses merged-usr |

Enable services via preset files, never `systemctl enable`. Example from Tailscale:

```yaml
install-commands:
  - |
    sed -e 's|/usr/sbin/tailscaled|/usr/bin/tailscaled|g' \
        -e '/^EnvironmentFile=/d' \
        systemd/tailscaled.service > tailscaled.service.patched
    install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system" tailscaled.service.patched
    mv "%{install-root}%{indep-libdir}/systemd/system/tailscaled.service.patched" \
       "%{install-root}%{indep-libdir}/systemd/system/tailscaled.service"
  - |
    install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-tailscale.preset" <<'PRESET'
    enable tailscaled.service
    PRESET
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Missing `strip-binaries: ""` | Required for non-ELF elements (fonts, configs, pre-built binaries) — build fails otherwise |
| Using `/usr/sbin` | Always `/usr/bin` — GNOME OS merged-usr |
| `EnvironmentFile=/etc/default/...` | GNOME OS doesn't use `/etc/default/`; remove these lines from upstream service files |
| Variables in source URLs | BuildStream doesn't support this; use literal URLs with aliases |
| Missing `%{install-extra}` | Must be last install-command — handles license files and metadata |
| Forgot to add element to `deps.bst` | Element builds but won't be included in the image |
| Wrong dependency stack | Use `freedesktop-sdk.bst:public-stacks/runtime-minimal.bst` for runtime deps; `buildsystem-*` stacks for build-deps |

## Related Skills

- `dakota-remove-package` — reverse workflow (safely removing a package)
- `dakota-package-binaries` — multi-arch pre-built binary dispatch
- `dakota-package-go` — Go project packaging approaches
- `dakota-package-rust` — Cargo/Rust packaging
- `dakota-oci-layers` — how `elements/oci/layers/` assembles the final image
- `dakota-patch-junctions` — adding patches to freedesktop-sdk or gnome-build-meta
- `dakota-debugging` — diagnosing and fixing build failures
- `dakota-update-refs` — updating junction refs to newer upstream versions
