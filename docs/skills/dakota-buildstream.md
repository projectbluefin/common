---
name: dakota-buildstream
description: Use when writing, editing, or reviewing BuildStream .bst element files in the projectbluefin/dakota repo — provides variable names, element kinds, source kinds, command hooks, systemd paths, and layer structure
---

# BuildStream Element Reference (dakota)

## Powerlevel

- **Level:** 2


Quick-reference for authoring `.bst` elements in the dakota project.

Load with: `cat ~/src/skills/dakota-buildstream/SKILL.md`

## Quick Recipes

| Goal | Command |
|------|---------|
| Validate element (dep graph, no build) | `just validate elements/bluefin/<name>.bst` |
| Build one element | `just bst build elements/bluefin/<name>.bst` |
| Enter build sandbox | `just bst shell --build elements/bluefin/<name>.bst` |
| Track a git ref | `just track-one elements/bluefin/<name>.bst` |
| Update tarball to new version | `just track-tarball elements/bluefin/<name>.bst <version>` |
| Scaffold binary element | `just scaffold-binary <name> <owner/repo>` |
| Scaffold GNOME extension | `just scaffold-gnome-ext <name> <owner/repo>` |
| Scaffold Rust element | `just scaffold-rust <name> <owner/repo>` |
| List reverse deps | `just reverse-deps elements/bluefin/<name>.bst` |
| Print CI tracking snippet | `just register-tracking elements/bluefin/<name>.bst auto-merge` |
| Full image build | `just build` |
| All available recipes | `just --list` |

## When to Use

- Looking up BuildStream variable names (`%{bindir}`, `%{indep-libdir}`, etc.)
- Checking element kinds, source kinds, or command hook syntax
- Reviewing or authoring a `.bst` file and need the reference tables
- Understanding how the layer chain assembles the OCI image

## When NOT to Use

- End-to-end workflow for adding a new package → use `dakota-add-package` instead
- Diagnosing build failures → use `dakota-debugging` instead
- Understanding the CI pipeline → use `dakota-ci` instead
- Managing junction overrides → use `dakota-bst-overrides` instead

## Variables

| Variable | Expands To | Notes |
|----------|-----------|-------|
| `%{install-root}` | Staging directory | Always prefix install paths with this |
| `%{prefix}` | `/usr` | |
| `%{bindir}` | `/usr/bin` | |
| `%{indep-libdir}` | `/usr/lib` | For systemd units, presets, sysusers, tmpfiles |
| `%{datadir}` | `/usr/share` | |
| `%{sysconfdir}` | `/etc` | Rarely used in GNOME OS elements |
| `%{install-extra}` | Empty hook | Convention: always end install-commands with this |
| `%{go-arch}` | `amd64`/`arm64`/`riscv64` | Defined in project.conf per-arch |
| `%{arch}` | `x86_64`/`aarch64`/`riscv64` | Raw architecture name |
| `strip-binaries` | Set to `""` to disable | Required for non-ELF elements (fonts, configs, pre-built) |
| `overlap-whitelist` | `public: bst: overlap-whitelist:` | List of paths allowed to overlap between elements. Declared under `public:` block |

## Element Kinds

| Kind | Use Case | Examples |
|------|----------|---------|
| `manual` | Custom build/install, pre-built binaries, config files | brew, brew-tarball, tailscale-x86_64, jetbrains-mono |
| `meson` | GNOME libraries/apps | gsconnect, ptyxis |
| `make` | Makefile projects, Go with vendored deps | podman, skopeo |
| `autotools` | Legacy C projects | grub, firewalld, openvpn |
| `make` + `cargo2` | Rust projects (actual pattern used) | just, bpftop, virtiofsd, bootc. See `dakota-package-rust` |
| `cmake` | CMake projects | fish |
| `import` | Direct file placement (no build) | systemd-presets |
| `stack` | Dependency aggregation, arch dispatch | deps.bst, tailscale.bst |
| `compose` | Layer filtering (exclude debug/devel) | bluefin-runtime.bst |
| `script` | OCI image assembly | oci/bluefin.bst |
| `collect_initial_scripts` | Collect systemd preset/sysusers/tmpfiles from deps | oci/layers/bluefin-stack.bst (gnome-build-meta plugin) |

## Source Kinds

| Source Kind | Use Case | Examples |
|-------------|----------|---------|
| `git_repo` | Most elements | brew, common, jetbrains-mono |
| `tar` | Release tarballs. Add `base-dir: ""` if the tarball has no wrapping directory (e.g., fzf ships a bare binary at root). Without it, BuildStream fails with `Could not find base directory matching pattern: *` | tailscale-x86_64, wallpapers, fzf |
| `remote` | Single file download (not extracted) | brew-tarball. Use `directory:` to place into a subdirectory (critical for Zig offline builds) |
| `local` | Files from repo's `files/` directory | plymouth-bluefin-theme |
| `cargo2` | Rust crate vendoring | bootc, just. Generate with `files/scripts/generate_cargo_sources.py` from Cargo.lock |
| `go_module` | Go module deps (one per dep) | git-lfs (in freedesktop-sdk) |
| `git_module` | Git submodule checkout | common (bluefin-branding) |
| `patch_queue` | Apply patches directory | toolbox |
| `gen_cargo_lock` | Generate Cargo.lock from base64 | zram-generator |

## Command Hooks

| Syntax | Meaning |
|--------|---------|
| `(>):` | Append to inherited command list from element kind |
| `(<):` | Prepend to inherited command list |
| `(@):` | Include a YAML file (like `rust-stage1-common.yml`) |
| `(?):` | Conditional block (evaluates options like `arch`) |

Convention: always end `install-commands` with `%{install-extra}` so downstream elements can extend.


## Extended Patterns + Project Options Reference

> **Multi-Arch, Zig Build, Layer Chain, Systemd, Go Packaging, Source Aliases, Chunkah Integration, Project Options (`project.conf`) syntax:**
> `cat ~/src/skills/dakota-buildstream/REFERENCE.md`

---

## BST Weak-Key Caching Bug (Non-Strict Mode)

**Symptom:** Adding a new package to `deps.bst` (`kind: stack`) does NOT trigger a rebuild of the downstream OCI image layers (`kind: compose`). The new package is missing from the final image even though `bst show` lists it.

**Root cause:** In BST non-strict mode (`bst build --no-strict`), the "weak key" for a `kind: stack` element is computed from its **direct dependency names only**, not their content hashes. Changing what a `compose` element transitively depends on (via a stack) does not change the compose element's weak key → BST considers it cache-hit → skips rebuild → new content never lands in the image.

**Workaround (works today):** Force-invalidate the cache of a `kind: compose` element that directly depends on a stack element by making any content change to one of its **direct** dependencies (e.g., remove or add a dependency directly in `gnome-shell-extensions.bst`, which is a direct dep of `oci/layers/bluefin.bst`). Even removing a single unrelated dep busts the weak key and forces the compose rebuild.

**Real fix (not yet implemented):** Use `bst build` in strict mode: `just bst --no-cache-buildtrees build oci/bluefin.bst`. Strict mode uses full content hashes and always rebuilds when transitive deps change. This is slower (all elements rebuild from scratch) but correct.

**Filed:** castrojo/dakota #153 (chunkah side-effect analysis; BST caching is the root cause for missing packages).

## ECL / Common Lisp Packaging Lessons

These apply when building ECL (Embeddable Common Lisp) or any element that uses `ecl --load`:

| Fact | Detail |
|---|---|
| Must use `-std=gnu99` | ECL's `fpe_x86.c` uses bare `asm()` which is NOT valid under `-std=c99`. Use `environment: CFLAGS: "-std=gnu99 -O2"` |
| Must use `--with-gmp=/usr` | Without this, ECL's configure bundles its own GMP and propagates the CFLAGS into it — `-fasm` from bundled GMP breaks that configure. System GMP avoids the cascade |
| `ecl --load` spawns `gcc` at runtime | Any element that calls `ecl --load file.lsp` at build time needs `gcc` in its `build-depends`. ECL calls `gcc` to compile loaded Lisp to native code |
| `gitlab.common-lisp.net` git sources | BST's dulwich cannot parse the git protocol from gitlab.common-lisp.net. Use `kind: tar` with GitLab's archive URL: `https://gitlab.common-lisp.net/<ns>/<repo>/-/archive/<ref>/<repo>-<ref>.tar.gz` |
| ECL installs to arch-qualified libdir | ECL places its library files at `/usr/lib/x86_64-linux-gnu/ecl-<version>/` (i.e., `%{libdir}/ecl-<version>/`, NOT `%{indep-libdir}`). Any downstream element building against ECL's static archives must use this path |
| Saturn upstream hardcodes Flatpak path | `src/meson.build` hardcodes `/app/lib/ecl-24.5.10/`. Patch via `sed` in `configure-commands` to replace `/app/lib/` with `/usr/lib/x86_64-linux-gnu/` |

## Known Planned (Not Yet Implemented) Features

| Feature | Status | Notes |
|---|---|---|
| `elements/bluefin/local-dev-registry.bst` | **Planned, not implemented** | Insecure registry config for QEMU VMs. Part of the local OTA registry plan. |

> **Note:** `just preflight`, `just registry-start`, `just registry-stop`, `just publish`, and `just vm-switch-local` are being added in castrojo/dakota PR #126. Run `just --list` to confirm whether they are present in your checkout.
