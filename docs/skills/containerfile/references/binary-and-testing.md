# Containerfile — Binary Verification & Local Testing

Part of [containerfile](../SKILL.md) — external binary SHA verification pattern, local testing with `just overlay`, adding a new binary, and Renovate tracking.

## External binary SHA verification pattern

Every external binary downloaded via `curl` is verified with an inline `sha256sum -c` check before use. The pattern is:

```dockerfile
RUN curl -fsSLo /path/to/binary https://... && \
    echo "<sha256>  /path/to/binary" | sha256sum -c && \
    chmod +x /path/to/binary
```

**Prefer a builder stage over curl downloads.** `umotd` was originally curl-downloaded with a SHA pin; it was migrated to a Go builder stage so no pre-built binary is fetched from an external release. Use builder stages for any first-party binary that can be compiled from source.

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
4. If the binary should be excluded from dakota, add `rm -f` lines to `dakota/elements/bluefin/common.bst` — see [`submodule-boundary.md`](../../submodule-boundary.md) for the pattern

---

## Renovate tracking for external deps

Renovate tracks OCI digest pins (the `@sha256:` references in FROM lines) via the `docker-compose` manager. External `curl` URL SHAs are **not** tracked by Renovate — they require manual updates. When the CI scan flags a CVE in a curl-downloaded binary, update manually:

1. Find the new release at the project's releases page
2. Download and `sha256sum`
3. Update both URL and hash in the Containerfile in one commit
