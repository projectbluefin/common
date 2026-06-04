---
name: dakota-package-binaries
description: Use when packaging a project in dakota that provides official pre-built static binaries, when building from source is impractical, or when you need a bootstrap compiler
---

# Packaging Pre-Built Binaries (dakota)

## Powerlevel

- **Level:** 1

Load with: `cat ~/src/skills/dakota-package-binaries/SKILL.md`

## When to Use

- Project provides official static binary releases (GitHub Releases, vendor CDN)
- Building from source is impractical (huge dep trees, incompatible toolchains)
- You need a bootstrap compiler (like the Zig SDK)

## When NOT to Use

- Packaging Go, Rust, or Zig projects that build from source → use `dakota-package-go`, `dakota-package-rust`, or `dakota-package-zig`
- Packaging apps with a standard build system (Meson, CMake, Make) → use `dakota-add-package`
- Updating a pre-built binary version → use `dakota-update-refs` for the manual bump workflow

## Required Settings

Every pre-built binary element MUST have:

| Setting | Why |
|---|---|
| `variables: strip-binaries: ""` | Pre-built binaries aren't ELF from our toolchain. Without this, build fails during strip phase. |
| `build-depends: freedesktop-sdk.bst:public-stacks/runtime-minimal.bst` | Provides `install`, `sed`, and other basic tools needed by install-commands. |

## Single-Arch Template

```yaml
kind: manual

build-depends:
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

sources:
  - kind: tar  # or 'remote' for single files
    url: github_files:org/repo/releases/download/vX.Y.Z/package_X.Y.Z_arch.tgz
    ref: <sha256>

variables:
  strip-binaries: ""

config:
  install-commands:
    - |
      install -Dm755 -t "%{install-root}%{bindir}" binary1 binary2
    - |
      install -Dm644 /dev/stdin "%{install-root}%{indep-libdir}/systemd/system-preset/80-name.preset" <<'PRESET'
      enable service-name.service
      PRESET
    - |
      %{install-extra}
```

## Multi-Arch Pattern

Binary tarball URLs almost always differ per architecture. BuildStream does NOT support variable substitution in `sources:` URLs or `(?):` conditionals on `sources:` blocks. The only option is a multi-arch dispatcher.

**Create these files:**

1. **Per-arch elements** — each with its own source URL and SHA256:
   - `elements/bluefin/package-x86_64.bst`
   - `elements/bluefin/package-aarch64.bst`

2. **Stack dispatcher** (`elements/bluefin/package.bst`):

```yaml
kind: stack

(?):
- arch == "x86_64":
    depends:
      - bluefin/package-x86_64.bst
- arch == "aarch64":
    depends:
      - bluefin/package-aarch64.bst
```

The dispatcher is what other elements depend on (and what you add to `deps.bst`).

## Systemd Service Patching for GNOME OS

Upstream service files often need patching:

- **`/usr/sbin/` → `/usr/bin/`** — GNOME OS uses merged-usr
- **Remove `EnvironmentFile=/etc/default/...`** — GNOME OS doesn't use `/etc/default/`
- **Enable via preset, NOT `systemctl enable`**

```bash
sed -e 's|/usr/sbin/|/usr/bin/|g' \
    -e '/^EnvironmentFile=/d' \
    upstream.service > patched.service
install -Dm644 -t "%{install-root}%{indep-libdir}/systemd/system" patched.service
```

## Source URL Patterns

- **GitHub Releases:** Use the existing `github_files:` alias — e.g., `github_files:org/repo/releases/download/vX.Y.Z/file.tgz`
- **Other domains:** Add a new alias to `include/aliases.yml` under the `# file aliases` section
- **SHA256 checksums:** Many projects publish `.sha256` files alongside releases

## Real Example: Tailscale

Multi-arch pre-built binary with systemd service. Three files:
- `elements/bluefin/tailscale-x86_64.bst` — amd64 tarball
- `elements/bluefin/tailscale-aarch64.bst` — arm64 tarball
- `elements/bluefin/tailscale.bst` — stack dispatcher

Key decisions:
- `github_files:` alias (Tailscale publishes to GitHub Releases)
- Patched service: `/usr/sbin/` → `/usr/bin/`, removed `EnvironmentFile=`
- Added `80-tailscale.preset` to enable `tailscaled.service`
- `strip-binaries: ""` (pre-built Go static binaries)

## Dependency Tracking

Pre-built binaries like Tailscale and Zig are **NOT tracked by any automated mechanism**. Updates are entirely manual:

1. Check upstream for a new release
2. Bump the version in the source URL
3. Update the SHA256 `ref:`
4. Test the build
5. Commit: `chore(deps): update <package> to v<version>`

See `dakota-update-refs` for the full manual bump workflow.

## Common Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Forget `strip-binaries: ""` | Build fails during strip phase | Always required |
| Use `/usr/sbin` in paths | Binary not found at runtime | Always use `%{bindir}` (`/usr/bin`) |
| Use `EnvironmentFile=/etc/default/` | Service fails to start | Remove directive |
| Use variables in source URLs | Wrong URL | Use multi-arch dispatcher pattern |
| Forget `%{install-extra}` | Breaks extensibility convention | Always end install-commands with it |
| Forget preset file | Service not enabled on boot | Add `80-<name>.preset` with `enable` |
| Tarball has no wrapping directory | `Could not find base directory matching pattern: *` | Add `base-dir: ""` to the `tar` source |

## Related Skills

- `dakota-update-refs` — version bump workflow for pre-built binary packages
- `dakota-package-zig` — Zig SDK bootstrap element follows this same pattern
