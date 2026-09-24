# Renovate, Trivy, Build Matrix, and Shellcheck

Part of [ci-tooling](../SKILL.md) — Renovate OCI digest tracking, Trivy scan-image archive input, multi-arch build matrix, Shellcheck in validate.yml, and Renovate versioned-binary tracking.

---

## Renovate OCI digest tracking

`Containerfile` has two OCI image pins tracked by Renovate:

1. `docker.io/library/alpine:latest@sha256:...` via Renovate's built-in `dockerfile` manager
2. `ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:...` via a custom regex manager in `.github/renovate.json5`

### Why both managers exist

- `FROM docker.io/library/alpine:latest@sha256:...` is a standard Dockerfile dependency — the built-in `dockerfile` manager handles it
- `COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:...` is not covered by the default parser — a custom regex manager tracks it

### Rule when adding OCI pins

If you add new OCI image pins to `Containerfile`, also update `.github/renovate.json5` so Renovate can keep them current. Applies to both `FROM` and `COPY --from=` references. An untracked pin silently goes stale.

### Org-wide Renovate runner

The factory runs self-hosted Renovate from `projectbluefin/renovate-config` (not from each image repo). It runs every 3 hours. To trigger immediately:

```bash
gh workflow run renovate.yml --repo projectbluefin/renovate-config
```

Image repos do **not** have their own `renovate.yml` caller workflow — Renovate runs org-wide from the central config repo using `RENOVATE_APP_ID` + `RENOVATE_PRIVATE_KEY` secrets (separate from `MERGERAPTOR_APP_ID`/`MERGERAPTOR_PRIVATE_KEY`).

---

## Trivy scan-image archive input

<!-- TODO(context7): verify trivy docker-archive input behavior and image: vs input: parameter semantics against trivy docs -->

When `build.yml` exports a locally built image with:

```bash
buildah push \
  "common:<tag>" \
  "docker-archive:/tmp/scan-image.tar:common:<tag>"
```

pass the archive to `projectbluefin/actions/bootc-build/scan-image` with:

```yaml
with:
  input: /tmp/scan-image.tar
```

**Do not** use `image: docker-archive:/tmp/scan-image.tar` with the current `build.yml` v1 pin (`e39c947...`). That path gets forwarded to `trivy image`, which then tries docker/containerd/podman/remote lookup instead of reading the tarball directly and fails on hosted runners.

---

## Multi-arch build matrix in build.yml

`build.yml` (as of [common#598](https://github.com/projectbluefin/common/pull/598)) runs parallel per-arch jobs:

```yaml
strategy:
  matrix:
    include:
      - arch: x86_64
        runs_on: ubuntu-24.04
        arch_suffix: amd64
      - arch: aarch64
        runs_on: ubuntu-24.04-arm
        arch_suffix: arm64
```

Each job:
1. Builds the image with `buildah-build` tagged `<image>:<sha>-<arch_suffix>`
2. Exports to `/tmp/scan-image.tar` with `buildah push ... docker-archive:...`
3. Scans via `scan-image` with `input: /tmp/scan-image.tar`
4. On non-PR: pushes the arch-specific image and writes digest to `/tmp/digests/<arch_suffix>.txt`

A separate `manifest` job then downloads both digest artifacts, creates the multi-arch manifest, signs with keyless OIDC, and generates SBOM + SLSA L2 attestations.

---

## Shellcheck in validate.yml

`validate.yml` runs shellcheck on all `.sh` files under `system_files/` plus the non-extension helper `ublue-rollback-helper`.

### The expand pattern

```yaml
- name: Shellcheck all shell scripts
  shell: bash
  run: |
    find system_files -name "*.sh" -print0 | xargs -0 shellcheck -e SC2207
    shellcheck -e SC2207 system_files/bluefin/usr/bin/ublue-rollback-helper
```

`ublue-rollback-helper` has no `.sh` extension so it is not caught by `find` — it needs an explicit second line.

### Profile.d files — SC2148 (no shebang)

Profile.d files are **sourced** by the shell, never executed directly. They legitimately have no shebang. Shellcheck requires a shell directive instead:

```sh
# shellcheck shell=bash
alias open="xdg-open &>/dev/null"
```

Add `# shellcheck shell=bash` as the first line of any profile.d file that:
- Declares functions or aliases
- Uses bash-specific syntax (`&>`, `local`, arrays, etc.)

### Runtime-only sourced files — SC1091 (not following)

Files sourced at runtime (e.g., `bash-preexec.sh` from Homebrew or `/etc/profile.d/`) do not exist in the repo. Add `# shellcheck source=/dev/null` immediately before each source line:

```sh
# shellcheck source=/dev/null
[ -f "/etc/profile.d/bash-preexec.sh" ] && . "/etc/profile.d/bash-preexec.sh"
```

This applies per-source-line, not to the whole file.

### SC2207 (global suppress)

SC2207 (arrays from command output) is suppressed globally in the shellcheck step with `-e SC2207`. This was intentional for `ublue-rollback-helper` which parses skopeo tag lists — tag names contain no spaces so word splitting is safe there. Evaluate case by case before adding new array-from-command patterns.

> **See also:** [`shell-scripts.md`](../../shell-scripts/SKILL.md) for shellcheck directive pitfalls (SC1072/SC1073 inline notes, SC2086 quoting fixes, SC1091 suppression patterns in test contexts).

---

## Renovate versioned-binary tracking

`.github/renovate.json5` tracks versioned binaries downloaded in the build stage via custom regex managers:

| Binary | Source | Renovate pattern |
|---|---|---|
| `bonedigger` | `projectbluefin/bonedigger` GitHub releases | `BONEDIGGER_VERSION` in `system_files/bluefin/usr/share/ublue-os/just/60-bonedigger.just` |
| `opentabletdriver` | `OpenTabletDriver/OpenTabletDriver` GitHub releases | `OTD_RELEASE="v…"` in `system_files/shared/usr/share/ublue-os/just/apps.just` |

When adding a new binary pinned to a specific version in a script or just file, add a corresponding regex manager entry in `renovate.json5` so the version stays current automatically.

### Pinned release fetches with sha256 verification (projectbluefin/common#1170)

`install-opentabletdriver` pins both fetches and verifies them with `sha256sum -c -` before anything is extracted, copied as root, or enabled:

- the release tarball: pinned tag in `OTD_RELEASE` (Renovate-tracked above) plus a `sha256:` digest for the exact asset;
- the flathub `opentabletdriver.service` unit: pinned to a full commit SHA plus its own sha256 — never fetch a moving branch ref (`refs/heads/…`) for something that gets installed.

**Coupling to know:** Renovate PRs update `OTD_RELEASE` only. The two hashes are not managed by Renovate — a version bump fails the recipe's checksum gate (fail-closed, never fail-open) until the hashes are updated manually in the same PR. Compute them with `sha256sum` against the new release asset and the raw file at the pinned ref. Tests in `tests/test_apps_just.bats` mirror these pins as constants and must move with them.
