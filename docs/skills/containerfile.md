---
name: containerfile
description: >-
  Documents the projectbluefin/common Containerfile build structure, multi-stage
  pattern, non-obvious build-time sources, SHA verification conventions, and the
  just overlay recipe for local systemd-sysext testing. Use when modifying the
  Containerfile, adding external binaries, updating wallpaper sources, or testing
  common layer changes locally without a full container build.
metadata:
  type: procedure
---

# Containerfile — common OCI layer build

## Contents
- [Build stages](#build-stages)
- [Wallpaper source caveat](#wallpaper-source-caveat)
- [ujust completion generation](#ujust-completion-generation)
- [External binary SHA verification pattern](#external-binary-sha-verification-pattern)
- [Local testing with just overlay](#local-testing-with-just-overlay)
- [Adding a new external binary](#adding-a-new-external-binary)
- [Renovate tracking for external deps](#renovate-tracking-for-external-deps)

---

## Build stages

The Containerfile uses two named stages:

```
FROM alpine:latest@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4 AS build
  └─ downloads + builds artifacts into /out/{shared,bluefin}/
       ├─ wallpapers
       ├─ ujust completions (generated from just binary)
       ├─ game-devices-udev rules
       ├─ U2F udev rules
       └─ umotd binary

FROM scratch AS ctx
  └─ COPY /system_files/* into layered paths
  └─ COPY --from=build /out/* into same paths
```

The final `ctx` stage is a scratch image — it contains only the file tree that downstream image builds overlay onto their base. There is no executable entry point.

---

## Wallpaper source caveat

**The wallpaper source is still `ghcr.io/ublue-os/bluefin-wallpapers-gnome`.**

```dockerfile
COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:... / /out/bluefin/usr/share
```

This is a build-time `COPY --from` image reference, not a runtime registry path. The production image tree lives in `ghcr.io/projectbluefin/`, but the wallpaper artwork still originates from the `ublue-os` artwork registry. This is intentional — the wallpapers are upstream artwork, not projectbluefin-owned infrastructure.

**Implication:** Updating the wallpaper source requires updating this SHA. The path `ghcr.io/ublue-os/bluefin-wallpapers-gnome` is NOT a violation of the ublue-os prohibition — it is a read-only upstream artwork source, not a write action to a ublue-os repo.

After copying, the wallpaper XML metadata paths are rewritten from `~/.local/share` to `/usr/share` to work correctly as system-installed assets:

```bash
sed -i 's|~\/\.local\/share|\/usr\/share|' *.xml
```

---

## ujust completion generation

The `ujust` shell completions are **not hand-authored** — they are generated at build time from the `just` binary by replacing all occurrences of `just` with `ujust` in the completion output:

```bash
just --completions bash | sed -E 's/([\(_" ])just/\1ujust/g' > .../completions/ujust
just --completions zsh  | sed -E 's/([\(_" ])just/\1ujust/g' > .../_ujust
just --completions fish | sed -E 's/([\(_" ])just/\1ujust/g' > .../ujust.fish
```

The sed pattern `([\(_" ])just` only substitutes `just` when preceded by `(`, `_`, `"`, ` `, or `(` — avoiding substring matches inside longer words. Do not edit the generated completions directly; edit the sed pattern if the substitution is wrong.

---

## External binary SHA verification pattern

Every external binary downloaded via `curl` is verified with an inline `sha256sum -c` check before use. The pattern is:

```dockerfile
RUN curl -fsSLo /path/to/binary https://... && \
    echo "<sha256>  /path/to/binary" | sha256sum -c && \
    chmod +x /path/to/binary
```

**Never add a `curl` download without a paired `sha256sum -c` check.** CI shellcheck will not catch missing SHA checks; this is a supply chain gate enforced by code review.

When updating a binary version:
1. Download the new binary locally
2. Run `sha256sum <file>` to get the new hash
3. Update both the URL and the hash in the same commit

---

## Local testing with just overlay

Use `just overlay` to test `system_files/` changes locally without a full container build. This creates a **systemd-sysext** (erofs image) that can be applied to a running Bluefin system:

```bash
# Build sysext from local system_files/ (default: merge shared + bluefin)
just overlay

# Build sysext from shared/ only (no Bluefin-specific files)
just overlay BLUEFIN_MERGE=0

# Build sysext from the published image instead of local files
just overlay SOURCE=image
```

The recipe:
1. Copies `system_files/shared/` (and optionally `system_files/bluefin/`) into a temp dir
2. Applies SELinux file contexts via `setfiles`
3. Packs the result into `bfincommon.raw` (erofs format)

**SELinux note:** `just overlay` calls `sudo setfiles` and `sudo chcon` — it requires sudo on the host. Without correct SELinux labels, the sysext may cause AVC denials when activated.

To activate the sysext on a running Bluefin system:
```bash
sudo cp bfincommon.raw /var/lib/extensions/
sudo systemd-sysext refresh
```

**Limitation:** `just overlay SOURCE=image` exports the current published `ghcr.io/projectbluefin/common:latest` — this is useful for comparing local changes against the shipped layer, not for testing local edits.

---

## Adding a new external binary

1. Add a `RUN` block to the `build` stage following the SHA verification pattern above
2. Place the binary in `/out/shared/` (available to all downstream variants) or `/out/bluefin/` (Bluefin-specific)
3. After the build stage, downstream images receive the binary at the corresponding `system_files/` path
4. If the binary should be excluded from dakota, add `rm -f` lines to `dakota/elements/bluefin/common.bst` — see [`submodule-boundary.md`](submodule-boundary.md) for the pattern

---

## Renovate tracking for external deps

Renovate tracks OCI digest pins (the `@sha256:` references in FROM lines) via the `docker-compose` manager. External `curl` URL SHAs are **not** tracked by Renovate — they require manual updates. When the CI scan flags a CVE in a curl-downloaded binary, update manually:

1. Find the new release at the project's releases page
2. Download and `sha256sum`
3. Update both URL and hash in the Containerfile in one commit
