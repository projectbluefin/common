# How common Updates Reach Downstream Builds

Part of [release-promotion](../SKILL.md) — the three consumption paths, what triggers each, and the trigger gap in the fast path.

---

## The three ways downstream consumes `common`

| Consumer | How it consumes | Tracker |
|---|---|---|
| `bluefin` | OCI layer — `Containerfile` defaults `ARG COMMON_IMAGE="ghcr.io/projectbluefin/common:latest"` | `.github/workflows/track-common.yml` |
| `bluefin-lts` | OCI layer — `Justfile` defaults `common_image := env("COMMON_IMAGE", "ghcr.io/projectbluefin/common:latest")` | `.github/workflows/track-common.yml` |
| `dakota` | **git source**, not OCI — `elements/bluefin/common.bst` is a BuildStream `git_repo` on `github:projectbluefin/common.git`, `track: main`, at a pinned `ref`, plus two local patches under `patches/common/`. Copies `system_files/shared/usr` and `system_files/bluefin/usr` into the image | `.github/workflows/track-bst-sources.yml` |

`projectbluefin/iso` git-clones `common` at build time for the Brewfiles. There is **no** direct dispatch from `common/build.yml` to anyone — the `notify-downstream` job was removed because cross-repo token dispatch failed silently.

---

## bluefin and bluefin-lts — `track-common.yml`

Both repos ship an identical workflow whose triggers are exactly:

```yaml
on:
  repository_dispatch:
    types: [common-updated]
  workflow_dispatch:
```

It `skopeo inspect --raw docker://ghcr.io/projectbluefin/common:latest`, compares the digest against `image-versions.yml`, and if it changed opens a `chore(deps): update common digest` PR on branch `auto/track-common` against `testing`, using the mergeraptor app token.

**The gap: nothing sends `common-updated`.** `common` has no `repository_dispatch` step in any workflow, so the only trigger that actually fires is a manual `workflow_dispatch`. Treat this path as manual until either `build.yml` gains a dispatch step or the tracker gains a cron.

To run it now:

```bash
gh workflow run track-common.yml --repo projectbluefin/bluefin
gh workflow run track-common.yml --repo projectbluefin/bluefin-lts
```

This is not Renovate. Renovate does not track the `common` digest in either repo; `track-common.yml` does, and it reads the `:latest` tag by name.

---

## dakota — `track-bst-sources.yml`

Triggers: `repository_dispatch: [common-updated]`, `schedule: '0 6 * * *'`, and `workflow_dispatch` with a `group` choice input. The daily cron is the live path, so dakota picks up a `common/main` commit within ~24 hours without anyone doing anything.

Tracking resolves refs only — it never builds and never touches the CAS, which is why it runs in its own `dakota-source-track` concurrency group rather than behind multi-hour BST builds.

To poke it:

```bash
gh workflow run track-bst-sources.yml --repo projectbluefin/dakota -f group=auto-merge
```

---

## Consequence for hotfixes

A `common` fix is in `ghcr.io/projectbluefin/common:latest` as soon as `build.yml` finishes. Reaching a downstream *image* takes a tracker PR plus a downstream build. `dakota` gets there on its own within a day via daily cron; `bluefin` and `bluefin-lts` do not move until someone dispatches `track-common.yml`. Say so explicitly when you hand off an urgent fix.
