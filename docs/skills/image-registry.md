---
name: image-registry
version: "1.1"
last_updated: "2026-09-13"
id: image-registry
one_line_purpose: Look up projectbluefin OCI image registry paths and tags.
entry_point: docs/skills/image-registry.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [registry, ghcr, images]
description: >-
  projectbluefin OCI image registry reference — all production images
  published at ghcr.io/projectbluefin/. Use when looking up image paths,
  tags, or registry structure.
metadata:
  type: reference
---

# Image Registry

All Bluefin images are published to `ghcr.io/projectbluefin/`. The org migration from `ublue-os` is complete — `projectbluefin` is fully standalone.

> **Do not write image names or tags from memory.** This file is derived from source.
> Re-derive any time you suspect drift — see [Verification](#verification) below.

## Registry paths

> **Tags differ by repo — `common` and the product images do not share a tag vocabulary.** The product images (`bluefin`, `bluefin-lts`, `dakota`) publish stream tags only; `common` publishes `latest` plus a date and a short SHA. Derive both from the workflow files, never from memory.

### bluefin (from `projectbluefin/bluefin`)

Builds flavors `main` and `nvidia` via `build-image-testing.yml`.
Release promotes `:testing` → `:stable`.

| Image | `:testing` | `:stable` |
|---|---|---|
| `ghcr.io/projectbluefin/bluefin` | ✅ pre-promotion | ✅ released |
| `ghcr.io/projectbluefin/bluefin-nvidia` | ✅ pre-promotion | ✅ released |

### bluefin-lts (from `projectbluefin/bluefin-lts`)

Builds `main`, `hwe`, and `hwe-nvidia` flavors.
Release promotes `:testing` → `:lts`; `:stable` is a floating alias for `:lts` created post-release.

| Image | `:testing` | `:lts` | `:stable` |
|---|---|---|---|
| `ghcr.io/projectbluefin/bluefin-lts` | ✅ pre-promotion | ✅ released | ✅ alias for :lts |
| `ghcr.io/projectbluefin/bluefin-lts-hwe` | ✅ pre-promotion | ✅ released | ✅ alias for :lts |
| `ghcr.io/projectbluefin/bluefin-lts-hwe-nvidia` | ✅ pre-promotion | ✅ released | ✅ alias for :lts |

### dakota (from `projectbluefin/dakota`)

| Image | `:testing` | `:stable` |
|---|---|---|
| `ghcr.io/projectbluefin/dakota` | ✅ pre-promotion | ✅ released |
| `ghcr.io/projectbluefin/dakota-nvidia` | ✅ pre-promotion | ✅ released |

### common (from `projectbluefin/common`)

`build.yml`'s `manifest` job creates one multi-arch manifest and applies three tags to it:

| Tag | Value | Source |
|---|---|---|
| `latest` | always the most recent merge to `main` | `build.yml` `create-manifest` `tags:` |
| `YYYYMMDD` | build date | `build.yml` step `manifest-tags` output `date` |
| `<sha7>` | short commit SHA | `build.yml` step `manifest-tags` output `sha_short` |

The per-arch `build_push` jobs additionally push `<sha7>-amd64` and `<sha7>-arm64`; those are manifest inputs, not consumption targets. `pr-e2e.yml` pushes ephemeral `e2e-pr-<n>-<sha7>` / `e2e-merge-group-<sha7>` composed test images.

| Image | Tags |
|---|---|
| `ghcr.io/projectbluefin/common` | `latest`, `YYYYMMDD`, `<sha7>` |

`:latest` is what downstream actually consumes: `bluefin/Containerfile` defaults `ARG COMMON_IMAGE="ghcr.io/projectbluefin/common:latest"`, `bluefin-lts/Justfile` defaults `common_image := env("COMMON_IMAGE", "ghcr.io/projectbluefin/common:latest")`, and `track-common.yml` in both repos resolves the digest with `skopeo inspect docker://ghcr.io/projectbluefin/common:latest`.

## Image flavor naming

The Justfile `image_name` recipe determines the published image name:
```
flavor=main  → image name = {image}          (e.g. bluefin, bluefin-lts)
flavor=other → image name = {image}-{flavor}  (e.g. bluefin-nvidia, bluefin-lts-hwe-nvidia)
```

Active flavors per repo (source: `build-image-testing.yml` / `build-regular.yml` / `build-nvidia.yml`):

| Repo | Flavor | Published image |
|---|---|---|
| bluefin | `main` | `bluefin` |
| bluefin | `nvidia` | `bluefin-nvidia` |
| bluefin-lts | `main` | `bluefin-lts` |
| bluefin-lts | `main` (hwe kernel) | `bluefin-lts-hwe` |
| bluefin-lts | `nvidia` (hwe kernel) | `bluefin-lts-hwe-nvidia` |
| dakota | `default` | `dakota` |
| dakota | `nvidia` | `dakota-nvidia` |

**Do not confuse with upstream package names:** `akmods-nvidia-open` is a `ublue-os` kernel module package pulled at build time — its name is NOT our image name. The image is `bluefin-nvidia`, not `bluefin-nvidia-open`.

## How runtime tools derive the registry path

```bash
IMAGE_VENDOR="$(jq -r '."image-vendor"' < /usr/share/ublue-os/image-info.json)"
IMAGE_REGISTRY="ghcr.io/${IMAGE_VENDOR}"
```

`image-vendor` is set at build time via `00-image-info.sh`. The helper reads it dynamically — do not hardcode the registry path.

## Build-time ublue-os source (wallpapers only)

The Containerfile pulls wallpaper artwork from `ghcr.io/ublue-os/bluefin-wallpapers-gnome` as a **build-time COPY source**. This is a read-only upstream artwork dependency and does not violate the ublue-os prohibition. The production image tree and all runtime registries are fully under `ghcr.io/projectbluefin/`. See [`containerfile/SKILL.md`](containerfile/SKILL.md) for details.

## CountMe telemetry reporting

Project Bluefin tracks Dakota installations labeled as "Bluefin" directly through its first-party CountMe service at `https://countme.projectbluefin.io/metalink`. Upstream Fedora bluefin numbers are maintained separately as the legacy "Bluefin Classic" chart from `ublue-os/bluefin`.

### What we count

Source: `system_files/shared/usr/libexec/bluefin-countme`, run weekly by
`bluefin-countme.timer`. Every client sends one anonymous GET to
`https://countme.projectbluefin.io/metalink` with these query parameters:

1. **`repo`:** `dakota` for Dakota images (`dakota*`), labeled and rendered as "Bluefin" by the first-party CountMe deployment. Other images (such as LTS) do not report via this script.
2. **`tag`:** the runtime stream, read from `/run/ublue-os/booted-image` when present (never just the build-time compose tag in `image-info.json`), then normalised to a primary stream.
3. **`flavor`:** `image-flavor` from `image-info.json`, default `main`.
4. **`gamemode`:** `1` when a gamescope/Steam session or gaming flavor is detected, else `0`.
5. **`arch`:** machine architecture.
6. **`countme`:** Fedora-style age bucket computed locally (1: week 1, 2: weeks 2–4, 3: weeks 5–24, 4: >24 weeks).

Opt-out is any of `/etc/projectbluefin/countme/disabled`, `/etc/bluefin-countme-opt-out`, or `/etc/dakota-countme/disabled`; the systemd unit and timer also carry `ConditionPathExists=!/etc/dakota-countme/disabled`.

### Policy on Upstream Counts
- **Never use Fedora / EPEL / `ublue-os/countme` numbers for Bluefin LTS or any other Project Bluefin image.** The single permitted exception is the legacy upstream `ublue-os/bluefin:stable` chart, published as "Bluefin Classic" to track the migration.
- Upstream pipelines undercount bootc, drop CS10/EPEL metalinks, and do not track modern streams or game mode status.
- The Cloudflare Worker and D1 database behind `countme.projectbluefin.io` are the single source of truth for first-party Project Bluefin telemetry, dashboards, and shields badges.
## Runtime repository selection

Repository routing for booted images is canonically resolved by
`/usr/libexec/ublue-image-repo` (consumed by `ujust changelogs` and
`bonedigger-report`). `dakota` images use `projectbluefin/dakota`, image names
starting with `bluefin-lts` use `projectbluefin/bluefin-lts`, and other Bluefin
image names use `projectbluefin/bluefin`. Do not infer the LTS repository from
the tag alone: LTS images may use `stable`, `testing`, or `lts` aliases.

Verify the runtime metadata and resolver together:

```bash
jq -r '."image-name", ."image-tag"' /usr/share/ublue-os/image-info.json
/usr/libexec/ublue-image-repo "$IMAGE_NAME" "$IMAGE_TAG"
```

## Verification

**Before editing this file or writing any image name or tag anywhere in the factory,
re-derive from the actual workflow files.** Do not use training data or copy from
other docs — they may be stale.

```bash
# common: what tags does the manifest job apply?
grep -A6 'Create multi-arch manifest' .github/workflows/build.yml

# bluefin: what images and tags does execute-release.yml publish?
gh api 'repos/projectbluefin/bluefin/contents/.github/workflows/execute-release.yml' \
  --jq '.content' | base64 -d | grep -A2 '"image"'

# bluefin-lts: what images and tags?
gh api 'repos/projectbluefin/bluefin-lts/contents/.github/workflows/execute-release.yml' \
  --jq '.content' | base64 -d | grep -A2 '"image"'

# bluefin: what flavors does the build matrix use?
gh api 'repos/projectbluefin/bluefin/contents/.github/workflows/build-image-testing.yml' \
  --jq '.content' | base64 -d | grep 'image_flavors'

# live tags in GHCR (cross-check):
gh api 'orgs/projectbluefin/packages/container/bluefin/versions' \
  --jq '.[].metadata.container.tags[]' | grep -v '^[0-9a-f]\{64\}$' | sort -u
```

This is how the tables above were derived. Run it, compare, update if anything differs.

`scripts/check-oci-refs.py`, run by `validate.yml`, resolves every
`ghcr.io/projectbluefin/IMAGE:TAG` written anywhere under `docs/` against live
GHCR. A tag you invent in this file fails the PR gate.
