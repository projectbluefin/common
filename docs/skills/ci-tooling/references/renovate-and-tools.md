# Renovate, Trivy, Build Matrix, and Shellcheck

Part of [ci-tooling](../SKILL.md) — which Renovate config actually governs, OCI digest tracking, Trivy scan-image archive input, the multi-arch build matrix, and shellcheck in `validate.yml`.

---

## Which Renovate config governs this repo

**Root `renovate.json` is the live config. `.github/renovate.json5` is dead.**

Renovate resolves its config file in a fixed precedence order and stops at the first hit; root `renovate.json` is ahead of `.github/renovate.json5`, so nothing in the json5 file is ever read. That includes its `schedule` (`* 0-3 * * 1`), its `enabledManagers`, and both of its `customManagers` (the wallpapers `COPY --from=` digest manager and the `BONEDIGGER_VERSION` manager). Those two managers are therefore **not** running, and those pins are **not** being tracked.

What root `renovate.json` actually contains:

```json
{
  "extends": ["local>projectbluefin/renovate-config"],
  "packageRules": [
    {
      "matchUpdateTypes": ["digest", "pin", "patch", "minor"],
      "automerge": true,
      "platformAutomerge": true
    }
  ]
}
```

Everything else — managers, schedule, host rules — comes from the org preset `local>projectbluefin/renovate-config`, which is not in this checkout. Do not restate its contents from memory; read that repo.

The live self-hosted bot inherits the preset via `inheritConfigRepoName: '{{parentOrg}}/renovate-config'`. The copy of that setting in `projectbluefin/.github` is stale and still points at `ublue-os/renovate-config`.

To trigger a run immediately:

```bash
gh workflow run renovate.yml --repo projectbluefin/renovate-config
```

`common` has no repo-local `renovate.yml` caller workflow — Renovate runs org-wide from the central config repo.

**If you add an OCI pin or a versioned binary that needs tracking,** put the custom manager in root `renovate.json` or in the org preset. Adding it to `.github/renovate.json5` silently does nothing.

---

## OCI image pins in Containerfile

`Containerfile` carries four digest-pinned refs:

| Line | Ref | Covered by |
|---|---|---|
| 1 | `docker.io/library/golang:alpine@sha256:cf6fca66…` (`umotd-build` stage) | built-in `dockerfile` manager |
| 8 | `docker.io/library/golang:alpine@sha256:cf6fca66…` (`uwelcome-build` stage, same digest) | built-in `dockerfile` manager |
| 15 | `docker.io/library/alpine:latest@sha256:28bd5fe8…` (`build` stage) | built-in `dockerfile` manager |
| 17 | `ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:47057248…` (`COPY --from=`) | **nothing** — the only manager written for it lives in the dead `.github/renovate.json5` |

`COPY --from=` is not covered by Renovate's default Dockerfile parser, so the wallpapers digest goes stale until the custom manager is moved into a config Renovate actually reads.

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

**Do not** use `image: docker-archive:/tmp/scan-image.tar` with the `projectbluefin/actions` pin `build.yml` currently carries (`e2ccd51b…`). That path gets forwarded to `trivy image`, which then tries docker/containerd/podman/remote lookup instead of reading the tarball directly and fails on hosted runners.

---

## Multi-arch build matrix in build.yml

`build.yml` runs parallel per-arch jobs ([common#598](https://github.com/projectbluefin/common/pull/598)):

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

The job is named `Build and push image (${{ matrix.arch }})`, which is where the ruleset's two required check names come from — see [workflow-map.md](../../workflow-map.md).

Each job:
1. Builds the image with `buildah-build` tagged `<image>:<sha>-<arch_suffix>`
2. Exports to `/tmp/scan-image.tar` with `buildah push ... docker-archive:...`
3. Scans via `scan-image` with `input: /tmp/scan-image.tar`
4. On non-PR: pushes the arch-specific image and writes digest to `/tmp/digests/<arch_suffix>.txt`

A separate `manifest` job then downloads both digest artifacts, creates the multi-arch manifest, signs with keyless OIDC, and generates SBOM + SLSA L2 attestations. The tags it publishes are in [image-registry.md](../../image-registry.md).

---

## Shellcheck in validate.yml

`validate.yml` runs exactly one shellcheck line:

```yaml
- name: Shellcheck all shell scripts
  shell: bash
  run: |
    find system_files -name "*.sh" -print0 | xargs -0 shellcheck -e SC2207
```

Extensionless scripts are **not** covered here — `unit-tests.yml` shellchecks those by explicit path (`ublue-system-setup`, `ublue-user-setup`, `ublue-privileged-setup`, …). If you add an extensionless script under `system_files/`, add it to `unit-tests.yml`, not to `validate.yml`.

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

SC2207 (arrays from command output) is suppressed globally in the `validate.yml` shellcheck step with `-e SC2207`. Evaluate case by case before adding new array-from-command patterns.

> **See also:** [`shell-scripts.md`](../../shell-scripts/SKILL.md) for shellcheck directive pitfalls (SC1072/SC1073 inline notes, SC2086 quoting fixes, SC1091 suppression patterns in test contexts).
