---
name: containerfile
version: "1.1"
last_updated: "2026-08-08"
id: containerfile
one_line_purpose: Modify and locally test the common Containerfile build.
entry_point: docs/skills/containerfile/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [containerfile, build, oci]
description: >-
  Containerfile build structure and local testing. Use when modifying the
  Containerfile, adding binaries, updating wallpaper sources, or using just
  overlay.
metadata:
  type: reference
---

# Containerfile — common OCI layer build

## When to Use

Use when modifying the `Containerfile`, adding new external binaries, updating
wallpaper sources, changing the `umotd`/`uwelcome` version pins, or running
`just overlay` to test `system_files/` changes locally.

## When Not to Use

Do not use this skill for changes that only affect `system_files/` content
without touching the Containerfile build stages, or for downstream image
Containerfiles outside `projectbluefin/common`.

## Build Stages Overview

The Containerfile uses four named stages:

| Stage | Purpose |
|---|---|
| `umotd-build` | Go builder for the MOTD tips binary |
| `uwelcome-build` | Go builder for the CLI welcome banner binary |
| `build` | Downloads and assembles all artifacts into `/out/` |
| `ctx` | Scratch image: the OCI layer consumed by downstream builds |

See [`references/build-stages.md`](references/build-stages.md) for the full stage details, wallpaper source caveat, and ujust completions.

## Key Rules

- **Never** download a pre-built binary for `umotd`/`uwelcome` — use the Go builder stage pattern.
- **Never** add a `curl` download without a paired `sha256sum -c` check.
- Git checkout pins must be commit SHAs, not tags or branch names.
- Place shared binaries in `/out/shared/`, Bluefin-specific in `/out/bluefin/`.

## Red Flags

- `checkout tags/...` or `--branch` in a Go builder stage — tags are mutable.
- A `curl` block without an inline `sha256sum -c`.
- Reintroducing a `just --completions | sed` generator for ujust completions, or shipping files at the ujust completion paths from `/out/shared/`, instead of editing the checked-in files under `system_files/shared/` — the `build` stage `RUN` gate fails the build.
- Using `ghcr.io/projectbluefin/` for the wallpaper source (it is `ublue-os`).

## Verification

- [ ] New binary has a builder stage or inline SHA check.
- [ ] Commit SHAs (not tags) used for `umotd`/`uwelcome` checkout.
- [ ] `just overlay` succeeds locally without SELinux AVC denials.
- [ ] Renovate OCI digest pins updated when FROM base images change.

## References

| File | Description |
|---|---|
| [`references/build-stages.md`](references/build-stages.md) | Full build stage definitions, wallpaper source caveat, and ujust completion details. |
| [`references/binary-and-testing.md`](references/binary-and-testing.md) | External binary SHA verification pattern, local testing with `just overlay`, adding a new binary, and Renovate tracking. |
