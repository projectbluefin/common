---
name: dakota-package-rust
description: Use when packaging a Rust project with Cargo.toml for dakota/Bluefin BuildStream, when an element needs cargo2 sources for offline builds, or when generating cargo dependency lists
---

# Packaging Rust/Cargo Projects (dakota)

## Powerlevel

- **Level:** 2

Load with: `cat ~/src/skills/dakota-package-rust/SKILL.md`

## When to Use

- Packaging a Rust/Cargo project for dakota/Bluefin BuildStream
- Generating `cargo2` source lists from a `Cargo.lock` using the helper script
- Setting up offline crate vendoring with `kind: cargo2` sources
- Handling setuid binaries or `overlap-whitelist` for files that replace upstream packages

## When NOT to Use

- Packaging Go projects → use `dakota-package-go` instead
- Packaging Zig projects → use `dakota-package-zig` instead
- General BuildStream element reference → use `dakota-buildstream` instead

## Overview

Rust projects in this BuildStream repo use `kind: make` elements with `cargo2` sources for offline dependency vendoring. The element overrides `build-commands` to call `cargo build --release` directly.

**Do NOT use `kind: cargo` elements or `kind: cargo` sources** — they don't exist in this project's plugin set.

## Element Kind and Build Dependencies

**Always use `kind: make`** with these build-depends:

```yaml
kind: make

build-depends:
  - freedesktop-sdk.bst:components/rust.bst
  - freedesktop-sdk.bst:public-stacks/buildsystem-make.bst
```

Both are required. `rust.bst` provides the Rust toolchain. `buildsystem-make.bst` provides the make build system that `kind: make` expects.

## Source Structure

```yaml
sources:
  # 1. Project source
  - kind: git_repo
    url: github:<org>/<repo>.git
    track: <ref-or-tag-pattern>
    ref: <commit-or-tag-ref>

  # 2. Cargo dependencies (offline vendored crates)
  - kind: cargo2
    ref:
      # Registry crates (from crates.io)
      - kind: registry
        name: <crate-name>
        version: <version>
        sha: <sha256>

      # Git-hosted crates (rare)
      - kind: git
        commit: <git-commit>
        repo: github:<org>/<repo>
        query:
          rev: <cargo-lock-rev-query>
        name: <crate-name>
        version: <version>
```

> ⚠️ **`commit:` and `query.rev:` serve different purposes and must NOT be made identical:**
> - `commit:` = full 40-char hash — used by BST to clone the git repo
> - `query.rev:` = the `rev=` query parameter from the Cargo.lock `source` field — must match **exactly** what appears in `Cargo.lock` (may be a 7-char abbreviated hash like `2203e8f` or a full hash depending on how the upstream Cargo.lock was written)
>
> Making them identical breaks the BST source cache key lookup — cargo will try to fetch the git dep at build time and fail with a network error in the sandboxed build environment. Always copy `query.rev:` verbatim from the Cargo.lock `source` URL.

**Critical:** The source kind is `cargo2`, NOT `cargo`. Each crate is listed under `ref:` with `kind: registry` (for crates.io) or `kind: git` (for git-hosted crates).

### Projects without Cargo.lock in repo

```yaml
sources:
  - kind: git_repo
    ...
  - kind: gen_cargo_lock
    ref: <base64-encoded-Cargo.lock-content>
  - kind: cargo2
    cargo-lock: Cargo.lock
    ref:
      - kind: registry
        ...
```

## Build and Install Commands

```yaml
config:
  build-commands:
    - cargo build --release

  install-commands:
    - install -Dm755 target/release/<binary> "%{install-root}/usr/bin/<binary>"
```

### Install Patterns

**Simple binary:**
```yaml
- install -Dm755 target/release/<binary> "%{install-root}/usr/bin/<binary>"
```

**Setuid binary** (e.g., sudo-rs replacing sudo):
```yaml
- install -Dm4755 target/release/sudo "%{install-root}/usr/bin/sudo"
- ln -sr "%{install-root}/usr/bin/sudo" "%{install-root}/usr/bin/sudoedit"
```

## Replacing Upstream Binaries (overlap-whitelist)

When your Rust binary intentionally replaces a file from an upstream dependency:

```yaml
public:
  bst:
    overlap-whitelist:
      - /usr/bin/sudo
      - /usr/bin/sudoedit
```

Without this, BuildStream will error on overlapping files during layer composition.

## Source Tracking — cargo2 Regeneration

**`bst source track` regenerates cargo2 automatically for existing elements.** You do not need to re-run `generate_cargo_sources.py` when updating an existing Rust element's version.

```bash
just track-one elements/bluefin/sudo-rs.bst   # updates git ref AND regenerates entire cargo2 block
```

This is confirmed by GNOME OS's `update-refs.py` pattern and dakota's CI matrix (sudo-rs, uutils-coreutils both tracked via `bst source track` in `manual-merge` group).

**`generate_cargo_sources.py` is only needed for initial bootstrap of a NEW Rust element** — the first time you create an element from the `files/templates/rust.bst` scaffold, before `bst source track` has anything to work with.

Summary:
| Situation | Tool |
|---|---|
| New element, no cargo2 block yet | `generate_cargo_sources.py` (once) |
| Updating existing element to new version | `just track-one` (regenerates automatically) |
| Reviewing crate list for a security audit | Read the `cargo2` block — it's the current lock state |

## Generating cargo2 Source Lists (Initial Bootstrap Only)

> ⚠️ **NEVER write cargo2 source blocks by hand.** They are generated output — not authored content. A typical Rust daemon has 300–700 crate entries. Writing them manually is both error-prone and wasted effort.

The helper script `files/scripts/generate_cargo_sources.py` reads a `Cargo.lock` and outputs the `cargo2` source YAML:

```bash
python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
```

This outputs registry crate entries. For git-hosted crates, add `kind: git` entries manually by inspecting the `Cargo.lock` for `source = "git+https://..."` entries.

**The element structure:** the first ~65 lines are the hand-authored element logic (build commands, install paths, config). Everything after that is the generated crate manifest — equivalent to a `Cargo.lock` in BST format. Only edit the top section.

## Element Template

```yaml
kind: make

build-depends:
  - freedesktop-sdk.bst:components/rust.bst
  - freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

config:
  build-commands:
    - cargo build --release

  install-commands:
    - install -Dm755 target/release/<binary> "%{install-root}/usr/bin/<binary>"

sources:
  - kind: git_repo
    url: github:<org>/<repo>.git
    track: <commit-or-tag>
    ref: <commit-or-tag>
  - kind: cargo2
    ref:
      - kind: registry
        name: <crate>
        version: <version>
        sha: <sha256>
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Using `kind: cargo` element | Wrong build behavior or element not found | Use `kind: make`, override `build-commands` |
| Using `kind: cargo` source | Source kind not found | Use `kind: cargo2` |
| Missing `buildsystem-make.bst` build-dep | Make-related errors | Add `freedesktop-sdk.bst:public-stacks/buildsystem-make.bst` |
| Missing `rust.bst` build-dep | `cargo` command not found | Add `freedesktop-sdk.bst:components/rust.bst` |
| Wrong install permissions for setuid | Binary lacks elevated privileges | Use `-Dm4755` not `-Dm755` for setuid binaries |
| Missing `overlap-whitelist` | Build fails with overlap error | Add `public.bst.overlap-whitelist` listing conflicting paths |
| Forgetting git crates in cargo2 | Build fails with unresolved dependency | Check Cargo.lock for `git+https://` sources, add `kind: git` entries |
