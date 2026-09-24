---
name: image-registry
version: "1.0"
last_updated: "2026-06-29"
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
  context7-sources:
    - /systemd/systemd
---

# Image Registry

All Bluefin images are published to `ghcr.io/projectbluefin/`. The org migration from `ublue-os` is complete — `projectbluefin` is fully standalone.

> **Do not write image names or tags from memory.** This file is derived from source.
> Re-derive any time you suspect drift — see [Verification](#verification) below.

## Registry paths

> **There is no `:latest` tag on any projectbluefin image.** Source: `execute-release.yml` in each repo.

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

### common

| Image | Status |
|---|---|
| `ghcr.io/projectbluefin/common` | ✅ Shared OCI layer consumed by all variants |

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

## Dakota CountMe reporting

Only Dakota currently publishes a first-party count. It ships
`/usr/libexec/bluefin-countme` and `bluefin-countme.{service,timer}` from this
repo through Dakota's pinned `elements/bluefin/common.bst`. The units require
`ID=bluefin-dakota`; the script also exits before reporting from other images.

The timer tries on activation and once per calendar day, so an offline attempt
can retry. The script records a success in `/var/lib/bluefin-countme/lastrun`
only after `/metalink` accepts the ping and sends at most once per UTC
Monday-anchored week. It reads `:stable` or `:testing` from the booted image
ref, including tagged digest refs. The baked `latest` tag is not a stream: if
the booted ref provides no valid stream, it retries instead of reporting it.
The opt-out is `systemctl mask --now bluefin-countme.timer bluefin-countme.service`.

`countme.projectbluefin.io/counts.json` derives Dakota's named stream counts
from its own D1 rows; other tags remain unclassified. These are estimated
check-ins without a machine identifier, not a distinct-device census. Fedora
countme and `ublue-os/countme` are not sources for Project Bluefin counts;
Bluefin Classic's upstream chart is separate.

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

This is how the current table was derived. Run it, compare, update if anything differs.

### Incident log

| Date | What was wrong | Root cause | Fix |
|---|---|---|---|
| 2026-06-19 | `bluefin:latest`, `bluefin-nvidia:latest`, `ublue-os/` refs in this file | Agent wrote from training data without reading workflow files | Read `execute-release.yml` and `build-image-testing.yml`; removed non-existent tags |
