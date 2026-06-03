---
name: dakota-local-ota
description: Use when setting up or understanding the local OTA update registry workflow for dakota — running a zot registry on the host, publishing built images to it, and pointing a QEMU VM at the local registry for bootc upgrade testing without pushing to GHCR
---

# Local OTA Registry (dakota)

## Powerlevel

- **Level:** 1

Load with: `cat ~/src/skills/dakota-local-ota/SKILL.md`

## When to Use

- Setting up or understanding the local zot OCI registry for dakota dev testing
- Testing a built image via `bootc upgrade` inside a QEMU VM without pushing to GHCR
- Implementing the planned `just registry-start`/`just publish` Justfile recipes
- Understanding the `elements/bluefin/local-dev-registry.bst` design

## When NOT to Use

- Building and exporting the OCI image → use the standard build workflow (`just build`)
- Understanding how the OCI image layers are assembled → use `dakota-oci-layers`
- Pushing to GHCR → handled automatically by the CI pipeline (`dakota-ci`)
- Debugging `bootc` failures unrelated to the local registry → use `dakota-debugging`

## Status

**IMPLEMENTED** (castrojo/dakota branch `feature/publish-plain-zstd`, 2026-04-19). The `just registry-start`, `just registry-stop`, `just registry-status`, `just publish`, `just preflight`, and `just vm-switch-local` recipes are in the Justfile. Validated end-to-end on ghost + NUC hardware (120 layers, GDM active after reboot).

The `elements/bluefin/local-dev-registry.bst` element does NOT yet exist (future work for QEMU VMs; NUC uses a manually placed `registries.conf.d` drop-in).

**Canonical VM install path:** use `just generate-bootable-image` (runs `bootc install to-disk --via-loopback --composefs-backend --bootloader systemd --filesystem btrfs` from inside the container). Do **not** run `bootc install` from outside the container.

## ⛔ Read Before Any Work

**Always run `just --list` in `~/src/dakota` first.** Verify that `just publish` exists (branch not yet merged to main).

## What This Solves

Today, a VM booted from a local build has its update source hardcoded to `ghcr.io/projectbluefin/dakota:latest`. Running `bootc upgrade` inside the VM tries to reach GHCR. There is no way to feed local builds back into a running VM as OTA updates without first pushing to a remote registry.

The local OTA registry workflow lets you:
- Build → publish to localhost:5000 → `bootc upgrade` inside the VM
- Full dev loop stays on-machine; never touches GHCR

## Architecture

```
Host                                          VM (QEMU)
----                                          ---------
just build
  |
  v
dakota:latest (podman)
  |
just publish
  |
  v
zot (localhost:5000/dakota:latest)  <---network---  bootc upgrade
                                      10.0.2.2:5000
```

QEMU's user-mode networking (already used by `just boot-vm`) exposes the host at `10.0.2.2` from inside the guest. No bridge, tap, or firewall config needed.

## Why zot?

- Single binary, ~15 MB image (`ghcr.io/project-zot/zot-minimal-linux-amd64`)
- OCI-native — no Docker legacy baggage
- Zero config for dev use (sane defaults)
- Standard in bootc development workflows

## Fast Iteration Alternative: just boot-fast (bcvk)

For smoke tests that don't need a full disk install, skip the registry entirely:

```bash
just build && just boot-fast
# Boots the built image in an ephemeral VM via virtiofs — no disk image, no registry
# bcvk auto-installs if missing (cargo install from github.com/bootc-dev/bcvk)
```

**When zot is needed vs when bcvk is enough:**
| Use zot + bootc upgrade | Use bcvk / just boot-fast |
|---|---|
| Testing the OTA update path | Smoke test: does it boot? |
| Validating composefs/ostree state | Quick package validation |
| Full btrfs install test | No disk image wanted |

## Implementation Plan

### 1. Add `elements/bluefin/local-dev-registry.bst`

This element drops two container config files into the image to allow `bootc` to pull from an insecure local registry:

```yaml
kind: manual

depends:
  - freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ""

config:
  build-commands:
    # Mark QEMU host gateway as insecure (HTTP) registry
    - mkdir -p %{install-root}%{sysconfdir}/containers/registries.conf.d/
    - |
      cat >"%{install-root}%{sysconfdir}/containers/registries.conf.d/50-local-dev.conf" <<'EOF'
      # Allow pulling images from the host's local registry when running inside
      # a QEMU VM with user-mode networking. 10.0.2.2 is QEMU's default gateway
      # to the host -- this address does not exist outside of QEMU VMs.
      [[registry]]
      location = "10.0.2.2:5000"
      insecure = true
      EOF

    # Allow unsigned image pulls from the local registry
    - mkdir -p %{install-root}%{sysconfdir}/containers/policy.json.d/
    - |
      cat >"%{install-root}%{sysconfdir}/containers/policy.json.d/50-local-dev.json" <<'EOF'
      {
        "transports": {
          "docker": {
            "10.0.2.2:5000": [
              {
                "type": "insecureAcceptAnything"
              }
            ]
          }
        }
      }
      EOF
```

Then add `- bluefin/local-dev-registry.bst` as a dependency of `elements/bluefin/deps.bst`.

These configs only affect `10.0.2.2:5000` — an IP that only exists inside QEMU VMs. No effect on production systems or CI builds.

### 2. Add Justfile Variables

Add after the VM settings block:

```just
# Local OTA registry settings
registry_name := "egg-registry"
registry_port := env("REGISTRY_PORT", "5000")
registry_image := "ghcr.io/project-zot/zot-minimal-linux-amd64:latest"
```

### 3. Add `just registry-start` Recipe

```just
# ── Local OTA Registry ───────────────────────────────────────────────
# Start a local zot OCI registry for serving updates to VMs.
[group('dev')]
registry-start:
    #!/usr/bin/env bash
    set -euo pipefail

    if podman container exists "{{registry_name}}" 2>/dev/null; then
        echo "Registry already running on port {{registry_port}}"
        podman ps --filter name="{{registry_name}}" --format "table {{{{.Names}}}}\t{{{{.Status}}}}\t{{{{.Ports}}}}"
        exit 0
    fi

    echo "==> Starting zot registry on port {{registry_port}}..."
    podman run -d \
        --name "{{registry_name}}" \
        --replace \
        -p "{{registry_port}}:5000" \
        -v egg-registry-data:/var/lib/registry \
        "{{registry_image}}"

    echo "==> Registry running. Push to localhost:{{registry_port}}/dakota:latest"
    echo "    VM can pull from 10.0.2.2:{{registry_port}}/dakota:latest"
```

### 4. Add `just registry-stop` and `just registry-status`

```just
[group('dev')]
registry-stop:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! podman container exists "{{registry_name}}" 2>/dev/null; then
        echo "Registry is not running."
        exit 0
    fi
    echo "==> Stopping registry..."
    podman stop "{{registry_name}}"
    echo "==> Registry stopped. Data preserved in 'egg-registry-data' volume."

[group('dev')]
registry-status:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! podman container exists "{{registry_name}}" 2>/dev/null; then
        echo "Registry is not running. Start with: just registry-start"
        exit 0
    fi
    podman ps --filter name="{{registry_name}}" --format "table {{{{.Names}}}}\t{{{{.Status}}}}\t{{{{.Ports}}}}"
    echo ""
    echo "==> Catalog:"
    curl -s "http://localhost:{{registry_port}}/v2/_catalog" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "(empty or unreachable)"
```

### 5. `just publish` Recipe (implemented)

The publish pipeline after chunkah uses **plain `podman push`** — the correct upstream-recommended path.

**Why plain podman push is correct post-chunkah:** `chunkah build` outputs an uncompressed OCI archive. `podman load` stores these as new content-addressed blobs in containers-storage — they are NOT the cached zstd:chunked blobs from the pre-chunkah image. `podman push` compresses them fresh as regular zstd. This is the same pattern as `tuna-os/tunaOS` (documented explicitly in their Justfile).

**If pushing a PRE-chunkah image** (e.g., raw BST export without rechunking): that image may have cached zstd:chunked blobs. In that case, the oci-dir export approach avoids the cache. But for the normal chunkah pipeline, plain `podman push` is correct.

**Pipeline:**
```
just chunkify → (chunkah produces OCI archive → podman load → plain podman push)
```

### 6. Add `just vm-switch-local` Convenience Recipe

```just
[group('dev')]
vm-switch-local:
    #!/usr/bin/env bash
    echo "Run this command INSIDE the VM to point it at the local registry:"
    echo ""
    echo "  sudo bootc switch 10.0.2.2:{{registry_port}}/{{image_name}}:{{image_tag}}"
    echo ""
    echo "This is a one-time operation. After switching, 'bootc upgrade' pulls from the local registry."
    echo "Dev loop: edit → just build → just publish → (in VM) sudo bootc upgrade"
```

## Dev Loop

```bash
# One-time setup: start the registry
just registry-start

# Check prerequisites (disk space, skopeo, image exists)
just preflight

# Build, chunkify, and publish
just build        # or: just export (if BST artifacts already pulled)
just publish      # chunkify → oci-dir → skopeo zstd push → manifest assert

# Boot the VM (first time: generate disk image first)
just generate-bootable-image   # if no disk image yet
just boot-vm

# Inside VM (one-time per disk image):
# FIRST: configure the insecure registry (--insecure flag does not exist in bootc)
sudo mkdir -p /etc/containers/registries.conf.d
printf '[[registry]]\nlocation = "10.0.2.2:5000"\ninsecure = true\n' | \
  sudo tee /etc/containers/registries.conf.d/local.conf
# THEN switch
sudo bootc switch 10.0.2.2:5000/dakota:latest

# Subsequent iterations:
# (host) just build && just publish
# (vm)   sudo bootc upgrade
```

**NUC (physical hardware) loop:**
```bash
# (ghost) just publish  — pushes to ghost:5000
# (NUC)  sudo bootc upgrade --check && sudo bootc upgrade
# (NUC)  sudo systemctl reboot
# (NUC)  systemctl is-active gdm && sudo bootc status --format=json
```

## Design Decisions

| Decision | Why |
|---|---|
| zot over distribution/distribution | ~15 MB, OCI-native, zero config, no Docker legacy |
| `10.0.2.2` over localhost | QEMU standard host gateway; works without bridge/tap setup |
| `bootc switch` (one-time) over build-time ref change | No changes to BuildStream elements or CI pipeline |
| `registries.conf.d` drop-in over global config | Scoped to `10.0.2.2:5000` only; no effect on production |
| Named podman volume for registry data | Images persist across `registry-stop`/`registry-start` cycles |
| Plain `podman push` after chunkah | After `chunkah build → podman load`, blobs are fresh and uncompressed — plain `podman push` is the correct upstream-recommended path (per coreos/chunkah README). The oci-dir/skopeo workaround is only needed when pushing a PRE-chunkah image that may have cached zstd:chunked blobs in containers-storage. |
| No TLS | Local-only dev tool; `10.0.2.2` / `192.168.1.102:5000` is unreachable from outside LAN |

> **zstd:chunked is BROKEN with bootc composefs (empirically confirmed, 2026-04-18, issue castrojo/dakota#119):**
> - Tested: `podman push --force-compression --compression-format=zstd:chunked` → correct annotations → `bootc upgrade` **still fails** at 8.19 kB with "unexpected EOF reading tar entry"
> - Root cause: bootc's composefs-oci uses a plain `ZstdDecoder` path. Cannot consume zstd:chunked blobs regardless of annotation correctness.
> - **After chunkah rechunking** (`chunkah build → podman load`), blobs are fresh uncompressed — plain `podman push` is safe and correct. The oci-dir workaround is NOT needed post-chunkah.
> - Plain zstd via plain `podman push` is the validated solution (120 layers, GDM active, no EOF — confirmed 2026-04-19/20).

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `REGISTRY_PORT` | `5000` | Port for the local zot registry |

## Future Work

- **Auto-switch at install time:** Modify `just generate-bootable-image` to run `bootc switch` before first boot, eliminating the manual step.
- **`just show-me-the-future` integration:** Optionally start registry and publish as part of the full pipeline.
- **bcvk integration:** `just show-me-the-future` could use `just boot-fast` as headless-safe alternative to `just boot-vm`
- **zstd:chunked is confirmed broken** — do not attempt. Plain zstd is the permanent solution.
- **Multi-arch support:** `publish` could push a manifest list.
- **Signing:** Add cosign for local image signing if signature verification is enforced.

## Cross-References

| Skill | When |
|---|---|
| `dakota-buildstream` | Understanding the `local-dev-registry.bst` element |
| `dakota-oci-layers` | OCI layer composition; `local-dev-registry.bst` is part of the Bluefin layer |
| `dakota-debugging` | Diagnosing `bootc upgrade` failures against the local registry |
