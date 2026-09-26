# Renovate, Trivy, Build Matrix, and Shellcheck

Part of [ci-tooling](../SKILL.md) — Renovate OCI digest tracking, Renovate fork processing in the org runner, Trivy scan-image archive input, multi-arch build matrix, Shellcheck in validate.yml, and Renovate versioned-binary tracking.

---

## Renovate OCI digest tracking

`Containerfile` has three OCI image pins (`docker.io/library/golang:alpine`, `docker.io/library/alpine:latest`, and `ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest`).

Renovate's built-in `dockerfile` manager natively parses `FROM` directives and directly-referenced `COPY --from=<image>` lines. The custom regex manager for `bluefin-wallpapers-gnome` in `renovate.json` explicitly pins and tracks wallpaper digest updates.

### Rule when adding OCI pins

When adding new OCI image pins to `Containerfile`, ensure Renovate can track them: standard `FROM` image pins are picked up by the built-in `dockerfile` manager, while non-standard or custom-referenced images can use a custom regex manager in `renovate.json`. An untracked pin silently goes stale.
### Org-wide Renovate runner

The factory runs self-hosted Renovate from `projectbluefin/renovate-config` (not from each image repo). It runs every 3 hours. To trigger immediately:

```bash
gh workflow run renovate.yml --repo projectbluefin/renovate-config
```

Image repos do **not** have their own `renovate.yml` caller workflow — Renovate runs org-wide from the central config repo using `RENOVATE_APP_ID` + `RENOVATE_PRIVATE_KEY` secrets (separate from `MERGERAPTOR_APP_ID`/`MERGERAPTOR_PRIVATE_KEY`).

### Fork processing in the org runner

Renovate's [documented default](https://docs.renovatebot.com/configuration-options/#forkprocessing) is to
skip forks: "By default, Renovate skips any forked repositories when in
`autodiscover` mode. It even skips a forked repository that has a Renovate
configuration file, because Renovate doesn't know if that file was added by the
forked repository." A fork is processed only when its **own `renovate.json`**
sets `"forkProcessing": "enabled"`; only the `onboardingConfigFileName`
(default `renovate.json`) is consulted, so a renamed or `.json5` config cannot
opt in.

The org runner relies on that default. `projectbluefin/renovate-config` sets
`autodiscover: true`, `requireConfig: "required"` and `inheritConfig` from
`org-inherited-config.json` in `renovate-config.json`, and none of its files
set `forkProcessing`. **Every `projectbluefin` repo that is a GitHub fork
therefore needs its own opt-in**, or it is discovered, silently skipped, and
never appears in a run log as processed.

The three printer application forks ([common#1242](https://github.com/projectbluefin/common/issues/1242))
now carry it:

| Fork | Config on `testing` | Opt-in | Manager scope in that config |
|---|---|---|---|
| [`ps-printer-app`](https://github.com/projectbluefin/ps-printer-app) | `renovate.json` (added) | [#33](https://github.com/projectbluefin/ps-printer-app/pull/33) | `enabledManagers: ["github-actions"]` |
| [`hplip-printer-app`](https://github.com/projectbluefin/hplip-printer-app) | `renovate.json` (existing) | [#36](https://github.com/projectbluefin/hplip-printer-app/pull/36) | `enabledManagers: ["custom.regex"]` |
| [`gutenprint-printer-app`](https://github.com/projectbluefin/gutenprint-printer-app) | `renovate.json` (existing) | [#38](https://github.com/projectbluefin/gutenprint-printer-app/pull/38) | none — inherits all managers |

Each also sets `baseBranchPatterns: ["testing"]` — the bot proposes into
`testing`, never `stable` — and turns automerge off for the pins it owns:
repo-wide in `hplip`, all `github-actions` updates in `ps`, and only the
`git-tags` source pin in `gutenprint`. The org preset still automerges grouped
non-major action pins elsewhere, and it applies its `automerge` label at the org
level regardless, so a labelled PR is **not** proof that automerge is enabled
for that repo — read the repo's own `packageRules`.

#### Verify by extraction, not by config syntax

A well-formed `renovate.json` proves nothing — a skipped fork logs no error and
opens no PR. Confirm the run actually reached the repo:

```bash
gh workflow run renovate.yml --repo projectbluefin/renovate-config
gh run list --repo projectbluefin/renovate-config --workflow renovate.yml --limit 1
gh run view <run-id> --repo projectbluefin/renovate-config --log \
  | grep -E 'repository=projectbluefin/(ps|hplip|gutenprint)-printer-app'
```

A processed repo logs `Repository started` → `Dependency extraction complete
(... baseBranch=testing)` → `Repository finished`. A fork without the opt-in
logs instead:

```text
INFO: Repository is a fork and not manually configured - skipping - did you
want to run with --fork-processing=enabled? (repository=projectbluefin/<repo>)
```

On run `36190076329` (2026-09-25T21:10Z) all three printer forks appear in the
autodiscovered list and are processed: `ps-printer-app` (21:20:32Z,
`github-actions`, 40 deps) and `gutenprint-printer-app` (21:21:07Z,
`github-actions` + `renovate-config` + `regex`, 35 deps) each created PRs in
that run; `hplip-printer-app` (21:20:56Z, `regex`, 3 deps) had no pending
update. The same run shows the skip line for twelve other org repos that are
forks, including `ghostscript-printer-app` and `chairlift`.

#### One writer per pin

Renovate has **no BuildStream manager** — `.bst` files are invisible to it. In
the printer forks each `elements/**/*.bst` pin therefore has exactly one
writer:

- the fork's own `customManagers` entry, for driver sources (`hplip.bst`,
  `net-snmp.bst`, `include/source-pins.yml`)
- that fork's scheduled `update-base.yml` (`just bst source track
  fsdk-containers.bst`), for the FSDK junction

No Renovate PR has ever targeted `elements/fsdk-containers.bst` in any of the
three repos, so the FSDK bump has no competing writer to remove. Keep this
property when adding pins: scope `enabledManagers` as `ps` and `hplip` do, and
never add a Renovate manager for a pin that `update-base.yml` already tracks.

`ps-printer-app` has **no** `custom.regex` source-pin manager yet — its config
is scoped to `github-actions`, so nothing in that repo's printing graph is
Renovate-tracked while the graph is still being built
([ps-printer-app#2](https://github.com/projectbluefin/ps-printer-app/issues/2)).

#### Bot identity

Renovate PRs are authored by the **Mergeraptor GitHub App**. GitHub reports the
PR author as `app/mergeraptor`, while the app's bot *user* — the identity the
in-repo `update-base.yml` commits as — is `mergeraptor[bot]` (user id
`267480593`). An author filter must match the surface it reads: `app/<slug>` on
a PR object, `mergeraptor[bot]` on a commit. The runner authenticates with
`RENOVATE_APP_ID`/`RENOVATE_PRIVATE_KEY`; `update-base.yml` uses
`MERGERAPTOR_APP_ID`/`MERGERAPTOR_PRIVATE_KEY`. Minting an app token *from a
fork* additionally needs `owner:` set to the repository owner — a fork's
per-repo installation lookup 404s (fsdk-containers#331).

#### Known gap: the HPLIP source pin has no resolvable digest

In the same run, `hplip-printer-app` logged `WARN: Package lookup failures` —
`Could not determine new digest for update (gitlab-tags package
printing-team/hplip.v2)`, `files: ["elements/printer-app/hplip.bst"]`. That
manager's `autoReplaceStringTemplate` emits `{{{newDigest}}}`, and the
`gitlab-tags` datasource supplies none, so Renovate can never propose the
coherent tag + dereferenced ref + version update for that pin.
`gutenprint-printer-app`'s equivalent manager uses `git-tags` against the salsa
git URL and resolves without a lookup failure. Fixing the HPLIP manager belongs
to [hplip-printer-app#8](https://github.com/projectbluefin/hplip-printer-app/issues/8).

> **Unrelated org-wide warning:** `Could not ensure issue ... integration-unauthorized`
> (dependency dashboard) appears for ~20 org repos in the same run, forks and
> non-forks alike. It is a runner app-permission condition, not a fork
> installation gap, and does not block PR creation.

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

`renovate.json` tracks versioned dependencies pinned as literals in scripts and just files via custom regex managers (they are fetched or consumed at runtime, not downloaded in the Containerfile build stage):

| Binary | Source | Renovate pattern |
|---|---|---|
| `bonedigger` | `projectbluefin/bonedigger` GitHub releases | `BONEDIGGER_VERSION` in `system_files/bluefin/usr/share/ublue-os/just/60-bonedigger.just` |
| `opentabletdriver` | `OpenTabletDriver/OpenTabletDriver` GitHub releases | `OTD_RELEASE="v…"` in `system_files/shared/usr/share/ublue-os/just/apps.just` |

When adding a new binary pinned to a specific version in a script or just file, add a corresponding regex manager entry in `renovate.json` so the version stays current automatically.

### Pinned release fetches with sha256 verification (projectbluefin/common#1170)

`install-opentabletdriver` pins both fetches and verifies them with `sha256sum -c -` before anything is extracted, copied as root, or enabled:

- the release tarball: pinned tag in `OTD_RELEASE` (Renovate-tracked above) plus a `sha256:` digest for the exact asset;
- the flathub `opentabletdriver.service` unit: pinned to a full commit SHA plus its own sha256 — never fetch a moving branch ref (`refs/heads/…`) for something that gets installed.

**Coupling to know:** Renovate PRs update `OTD_RELEASE` only. The two hashes are not managed by Renovate — a version bump fails the recipe's checksum gate (fail-closed, never fail-open) until the hashes are updated manually in the same PR. Because of that, `renovate.json` carries an `automerge: false` rule for `OpenTabletDriver/OpenTabletDriver`, so those PRs always wait for a human to add the new hashes. Compute them with `sha256sum` against the new release asset and the raw file at the pinned ref. Tests in `tests/test_apps_just.bats` mirror these pins as constants and must move with them.
