---
name: dakota-package-zig
description: Use when packaging a project that uses the Zig build system for dakota/Bluefin BuildStream, when an element needs zig fetch/build with offline dependency caching, or when adding Zig dependencies to an existing element
---

# Packaging Zig Projects (dakota)

## Powerlevel

- **Level:** 1

Load with: `cat ~/src/skills/dakota-package-zig/SKILL.md`

## When to Use

- Packaging a project that uses the Zig build system for dakota
- Setting up offline Zig dependency caching with `kind: remote` sources
- Populating the Zig global cache at build time using `zig fetch` and `place_git_dep()`
- Debugging transitive Zig dependencies or `systemIntegrationOption` runtime failures

## When NOT to Use

- Packaging Go projects → use `dakota-package-go` instead
- Packaging Rust/Cargo projects → use `dakota-package-rust` instead
- General BuildStream element reference → use `dakota-buildstream` instead

## Overview

Zig projects require offline dependency caching because BuildStream's bubblewrap sandbox has no network access during build. The pattern: fetch all dependencies as `remote` sources at source-fetch time, then populate Zig's global cache at build time using `zig fetch` (HTTP deps) and a `place_git_dep()` function (git deps).

## Prerequisites

A pre-built Zig SDK must exist as a build dependency. Create a `manual` element installing the Zig binary + stdlib from an official tarball (e.g., `bluefin/zig.bst`). See `dakota-package-binaries` for the pattern.

## Source Structure

```yaml
sources:
  # 1. Project source tarball
  - kind: tar
    url: <alias>:<path-to-release-tarball>
    ref: <sha256>

  # 2. HTTP Zig dependencies (one per dep)
  - kind: remote          # NOT 'tar' — opaque files for zig fetch
    url: <dep-url>
    ref: <sha256>
    directory: zig-deps   # All HTTP deps go in the same directory

  # 3. Git-based Zig dependencies (one per dep)
  - kind: remote          # Also 'remote', NOT 'git_repo'
    url: <archive-tarball-url>
    ref: <sha256>
    directory: zig-deps-git  # Separate directory from HTTP deps
```

**Critical:** Use `kind: remote` (not `tar`) for dependencies. `remote` downloads the file as-is without extracting. `zig fetch` handles extraction. HTTP deps share `directory: zig-deps`; git deps share `directory: zig-deps-git`.

## Build Commands

Three stages in `build-commands`:

### Stage 1: Set up Zig cache

```yaml
- |
  export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
  export ZIG_LIB_DIR="%{libdir}/zig"
  mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p"
```

### Stage 2: Populate cache from HTTP deps

```yaml
- |
  export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
  export ZIG_LIB_DIR="%{libdir}/zig"
  for dep in zig-deps/*; do
    zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "$dep" || true
  done
```

### Stage 3: Place git deps manually

GitHub/Codeberg archive tarballs have a top-level directory wrapper that differs from a git clone — `zig fetch` produces wrong content hashes. Extract manually:

```yaml
- |
  export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"

  place_git_dep() {
    local tarball="$1"
    local zig_hash="$2"
    local dest="$ZIG_GLOBAL_CACHE_DIR/p/$zig_hash"
    mkdir -p "$dest"
    tar xf "$tarball" --strip-components=1 -C "$dest"
  }

  # One call per git dep — hash comes from build.zig.zon
  place_git_dep "zig-deps-git/<commit>.tar.gz" "<zig-content-hash>"
```

**Where do Zig content hashes come from?** Run `zig fetch` on each git dep tarball locally (outside BuildStream) and note the hash it reports, OR read the `.hash` field in `build.zig.zon`.

## Install Commands

```yaml
install-commands:
  - |
    export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
    export ZIG_LIB_DIR="%{libdir}/zig"
    DESTDIR="%{install-root}" \
    zig build \
      --prefix /usr \
      --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" \
      -Doptimize=ReleaseFast \
      -Dcpu=baseline \
      -Dpie=true \
      -Demit-docs=false
```

**Key flags:**

| Flag | Purpose |
|---|---|
| `--global-cache-dir "$ZIG_GLOBAL_CACHE_DIR"` | Use pre-populated offline cache |
| `--prefix /usr` | Standard prefix |
| `DESTDIR="%{install-root}"` | Stage into BuildStream's install root |
| `-Doptimize=ReleaseFast` | Maximum performance |
| `-Dcpu=baseline` | Generic CPU target (no host-specific instructions) |
| `-Dpie=true` | Position-independent executable |
| `-Demit-docs=false` | Skip doc generation |

Use `--global-cache-dir` instead of `--system` unless you've verified every system library the project needs is in the SDK. `--system` forces ALL bundled C libraries to link against system `.so` files, causing hard-to-debug failures for missing libraries like bzip2, oniguruma, or gtk4-layer-shell.

## Handling `systemIntegrationOption`

When a Zig project has `.default = true` for a `systemIntegrationOption`, it forces use of the system library even without `--system`. The fix: package the missing library as a separate BuildStream element and add it as a runtime dependency. Example: Ghostty needs `gtk4-layer-shell` — solution was creating `bluefin/gtk4-layer-shell.bst`.

## Transitive Dependencies

Zig deps can have their own deps. Recursively check:

1. Read the project's `build.zig.zon` for top-level deps
2. For each git dependency, read ITS `build.zig.zon` for nested deps
3. Check `pkg/*/build.zig.zon` for nested package deps
4. Continue until all leaf nodes are reached

Example: Ghostty → vaxis → zigimg + zg (transitive deps that also need sources and `place_git_dep` calls).

## Element Template

```yaml
kind: manual

variables:
  strip-binaries: ""

build-depends:
  - bluefin/zig.bst
  - freedesktop-sdk.bst:components/tar.bst
  - freedesktop-sdk.bst:components/gzip.bst
  - freedesktop-sdk.bst:components/pkg-config.bst

depends:
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

sources:
  - kind: tar
    url: <release-tarball-url>
    ref: <sha256>
  - kind: remote
    url: <dep-url>
    ref: <sha256>
    directory: zig-deps
  - kind: remote
    url: <git-archive-tarball-url>
    ref: <sha256>
    directory: zig-deps-git

config:
  build-commands:
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      export ZIG_LIB_DIR="%{libdir}/zig"
      mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p"
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      export ZIG_LIB_DIR="%{libdir}/zig"
      for dep in zig-deps/*; do
        zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "$dep" || true
      done
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      place_git_dep() {
        local tarball="$1"; local zig_hash="$2"
        mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p/$zig_hash"
        tar xf "$tarball" --strip-components=1 -C "$ZIG_GLOBAL_CACHE_DIR/p/$zig_hash"
      }
      # place_git_dep "zig-deps-git/<file>" "<zig-hash>"

  install-commands:
    - |
      export ZIG_GLOBAL_CACHE_DIR="/tmp/zig-cache"
      export ZIG_LIB_DIR="%{libdir}/zig"
      DESTDIR="%{install-root}" \
      zig build --prefix /usr \
        --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" \
        -Doptimize=ReleaseFast -Dcpu=baseline -Dpie=true -Demit-docs=false
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Using `kind: tar` for deps | `zig fetch` fails | Use `kind: remote` — files must be opaque |
| Using `kind: git_repo` for git deps | Wrong content hash | Use `kind: remote` with archive tarball + `place_git_dep()` |
| Using `--system` when SDK lacks libraries | `unable to find dynamic system library` | Use `--global-cache-dir` instead |
| Wrong Zig content hash for git dep | "package not found" | Re-derive hash locally or check `build.zig.zon` |
| Mixing HTTP and git deps in same directory | Incorrect processing | HTTP → `zig-deps/`, git → `zig-deps-git/` |
| Missing `ZIG_LIB_DIR` export | Zig can't find its standard library | Set `export ZIG_LIB_DIR="%{libdir}/zig"` |
| Missing `strip-binaries: ""` | `freedesktop-sdk-stripper` fails | Required — Zig SDK doesn't include the stripper |
| Missing transitive deps | "package not found" for deps-of-deps | Recursively check `build.zig.zon` of git dependencies |
| `systemIntegrationOption` with `default=true` | Runtime: `cannot open shared object file` | Package the missing library as a separate element |

## Dependency Tracking

Zig elements are NOT tracked by any automation. Updates are manual — all dependency source entries (URLs and refs) change with each release. See `dakota-update-refs`.

## Real Example

`bluefin/ghostty.bst` packages Ghostty with 30+ Zig dependencies, 3 git deps with transitive deps, and a separate `bluefin/gtk4-layer-shell.bst` meson element for a system library Ghostty requires.
