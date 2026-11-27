---
name: image-registry
version: "1.0"
last_updated: "2026-11-14"
id: image-registry
one_line_purpose: Look up projectbluefin OCI image registry paths and wallpaper sources.
entry_point: docs/skills/image-registry.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
scope: on-device
dependencies: []
tags: [registry, ghcr, images, wallpapers]
description: >-
  projectbluefin OCI image registry and wallpaper source reference. Use when
  looking up image paths, tags, or registry structure, or repairing wallpapers.
metadata:
  type: reference
  context7-sources:
    - /systemd/systemd
---

# Image Registry

All Bluefin images are published to `ghcr.io/projectbluefin/`. The org migration from `ublue-os` is complete — `projectbluefin` is fully standalone.

The PR validation check (`scripts/check-oci-refs.py`) asks the registry
directly: one anonymous pull-token request per image, then one manifest `HEAD`
per documented tag, so its cost does not grow with an image's tag history. A
404 on the manifest, or a denied token for an unknown image, fails the check.
Registry outages leave tags unverified rather than reporting them missing.

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

## Wallpaper source and live repairs

The Containerfile pulls wallpaper artwork from `ghcr.io/projectbluefin/bluefin-wallpapers-gnome` as a **build-time COPY source**. The wallpaper package is built directly by `projectbluefin/artwork`. See [`containerfile/SKILL.md`](containerfile/SKILL.md) for details.

For desktop wallpaper repairs, use source images and XML metadata from
[`projectbluefin/artwork`](https://github.com/projectbluefin/artwork).
Installed Homebrew cask metadata can predate the organization migration;
resolve current asset paths in that repository before downloading.
Lazy Days uses `wallpapers/lazy-days/lazy-days.jxl` directly, not a cached PNG.
Compare the installed image with the current source: an older JXL can retain
image defects even when it decodes successfully.

## CountMe reporting (Dakota, Utah, and Server)

`/usr/libexec/projectbluefin-countme` and `projectbluefin-countme.{service,timer}`
ship from `system_files/shared` to every consumer; Dakota gets them through
its pinned `elements/bluefin/common.bst`, Utah through `COMMON_IMAGE_SHA`, and
Bluefin Server through its pinned `elements/bluefin-server/os-countme.bst`.
The script exits before any network call unless `image-info.json`'s
`image-name` starts with `dakota`, starts with `utah`, or is exactly `server`,
so Bluefin Classic and LTS never report.

The timer and service follow upstream
[`eos-phone-home`](https://github.com/endlessm/eos-phone-home): run on
activation and three hours after each run. The script sends at most once per
24h (`/var/lib/projectbluefin-countme/last`), only
`{"image": "<image-name>/<image-flavor>:<stream>"}` to
`PUT countme.projectbluefin.io/v1/ping`. The stream is the booted ref's tag
from `bootc status` (`stable`, `testing`, `latest`, else `unknown`), never the
baked `image-tag`. For Bluefin Server — a DDI updated by `systemd-sysupdate`
with no bootc image — the stream is taken from `image-info.json`'s `image-tag`
when no bootc ref is available (same `stable`/`testing`/`latest`, else
`unknown` normalisation), but only for images that are not bootc images; the
baked `image-tag` of a bootc image is the compose tag, not the stream it
actually runs. The unit uses trigger conditions
`ConditionDirectoryNotEmpty=|/home` and `ConditionPathExists=|!/run/ostree-booted`:
bootc hosts with an empty `/home` (live ISO, unattended host) are skipped,
while non-ostree hosts such as Server run regardless of `/home`. A failed
send exits 0 and the next timer run retries.

Opt out with `systemctl mask --now projectbluefin-countme.timer`. The previous
opt-outs still block the service: the files `/etc/projectbluefin/countme/disabled`,
`/etc/bluefin-countme-opt-out`, `/etc/dakota-countme/disabled`, and a
`systemctl mask` of `bluefin-countme.timer` or `bluefin-countme.service`.

`countme.projectbluefin.io/v1/daily.json` lists systems active per UTC day
and image. These are anonymous check-ins without a machine identifier, not a
device census. Fedora countme and `ublue-os/countme` are not sources for
Project Bluefin counts.

## Runtime repository selection

Repository routing for booted images is canonically resolved by
`/usr/libexec/ublue-image-repo` (consumed by `ujust changelogs`). `dakota` images
use `projectbluefin/dakota`; every other image name — including `bluefin` and
`bluefin-lts` — falls through to the caller-supplied default
(`projectbluefin/bluefin` for changelogs). The archived `projectbluefin/bluefin`
and `projectbluefin/bluefin-lts` destinations no longer keep their own routing,
so do not infer the repository from the image name or the tag: LTS images may
use `stable`, `testing`, or `lts` aliases.

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

# does one tag exist? (what the PR check does; 200 = yes, 404 = no)
tok=$(curl -s 'https://ghcr.io/token?scope=repository:projectbluefin/bluefin:pull' | jq -r .token)
curl -s -o /dev/null -w '%{http_code}\n' -I -H "Authorization: Bearer $tok" \
  -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json' \
  https://ghcr.io/v2/projectbluefin/bluefin/manifests/stable
```

This is how the current table was derived. Run it, compare, update if anything differs.

### Incident log

| Date | What was wrong | Root cause | Fix |
|---|---|---|---|
| 2026-06-19 | `bluefin:latest`, `bluefin-nvidia:latest`, `ublue-os/` refs in this file | Agent wrote from training data without reading workflow files | Read `execute-release.yml` and `build-image-testing.yml`; removed non-existent tags |
