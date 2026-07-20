---
name: image-registry
version: "1.0"
last_updated: "2026-06-29"
tags: [registry, ghcr, images]
description: >-
  projectbluefin OCI image registry reference — all production images
  published at ghcr.io/projectbluefin/. Use when looking up image paths,
  tags, or registry structure." type: reference
metadata:
  type: reference
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

The Containerfile pulls wallpaper artwork from `ghcr.io/ublue-os/bluefin-wallpapers-gnome` as a **build-time COPY source**. This is a read-only upstream artwork dependency and does not violate the ublue-os prohibition. The production image tree and all runtime registries are fully under `ghcr.io/projectbluefin/`. See [`containerfile.md`](containerfile.md) for details.

## CountMe telemetry reporting

Our images participate in Fedora's weekly CountMe telemetry to track installation statistics anonymously:
- **Bluefin & Bluefin LTS:** Handled by standard repository configuration, and since CentOS-based bootc images are broken with legacy rpm-ostree countme, they use a dnf5-based helper service.
- **Dakota:** Since it is based on GNOME OS and has no standard rpm-ostree/dnf packages, it utilizes a custom weekly systemd service/timer (`bluefin-countme.timer` triggering `/usr/libexec/dakota-countme`).
  - It generates and maintains an installation epoch cookie in `/var/lib/dakota-countme-epoch` to mimic Fedora's week-based age buckets.
  - It performs a weekly query to Fedora's metalink using a `libdnf5`-format User Agent with `os_name="Dakota"` (e.g. `libdnf5/5.2.9 (Dakota;${VERSION_ID};${ARCH}) hawkey`).

### Dashboard processing dependency

The results of Fedora's public CountMe dataset are parsed and processed by the pipeline inside the **`ublue-os/countme`** repository.

To make Dakota show up on the public active users count badges and charts:
1. **`data_processing.py`** in `ublue-os/countme` must have `"Dakota"` added to the `os_groups["universal_blue"]` list.
2. **`generate_badge_data.py`** in `ublue-os/countme` must have `"dakota"` defined in `project_mappings`.

Because of the **Absolute Prohibition** against write operations on `ublue-os/*` repositories, these updates cannot be automated or programmatically committed by agents, and must be submitted manually as a PR by a human maintainer.

## Runtime changelog repository selection

The `ujust changelogs` fallback chooses the upstream release repository from
`image-info.json`: `dakota` images use `projectbluefin/dakota`, image names
starting with `bluefin-lts` use `projectbluefin/bluefin-lts`, and other Bluefin
image names use `projectbluefin/bluefin`. Do not infer the LTS repository from
the tag alone: LTS images may use `stable`, `testing`, or `lts` aliases.

Verify the runtime metadata and recipe together:

```bash
jq -r '."image-name", ."image-tag"' /usr/share/ublue-os/image-info.json
rg -n 'IMAGE_NAME|bluefin-lts|REPO=' system_files/bluefin/usr/share/ublue-os/just/changelog.just
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
