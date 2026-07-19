---
name: ci-tooling
version: "2.0"
last_updated: 2026-06-24
tags: [ci, workflows, github-actions]
description: "Pre-commit floating-tag guard, SHA pinning policy, skill-drift workflow, Renovate OCI digest tracking, Trivy scan pattern, multi-arch build matrix, shellcheck CI config for projectbluefin repos. Use when editing .github/workflows/ files, enforcing SHA pinning, or understanding pre-commit policy guards."
metadata:
  type: procedure
  context7-sources:
    - /pre-commit/pre-commit.com
    - /sigstore/cosign
    - /containers/skopeo
    - /containers/buildah
    - /oras-project/oras
    - /anchore/syft
    - /anchore/grype
    - /aquasecurity/trivy
    - /renovatebot/renovate
    - /rhysd/actionlint
---

# CI tooling

> **Split notice (2026-06-24):** Incident-log / gotcha entries moved to [`ci-pitfalls.md`](ci-pitfalls.md). Shell script authoring and testability patterns moved to [`shell-scripts.md`](shell-scripts.md). This file retains CI policy and configuration.

## When to Use

- Editing `.github/workflows/` or `.pre-commit-config.yaml`
- Debugging pre-commit failures around floating tags, auto-fix hooks, or schema validation
- Updating shared CI policy that propagates across factory repos
- Auditing whether a workflow change belongs in repo-local CI or `projectbluefin/actions`

## When NOT to Use

- Debugging a silent CI failure or `startup_failure` with no output → [`ci-pitfalls.md`](ci-pitfalls.md)
- Writing or testing shell scripts under `system_files/` → [`shell-scripts.md`](shell-scripts.md)
- User-facing image content changes in `system_files/` or `Containerfile`
- Release promotion logic and stream semantics (use `release-promotion.md`)
- Issue lifecycle or queue automation (use `label-workflow.md` or bonedigger skills)
- One-off PR status checks with no reusable CI pattern to capture

---

## Core Process

1. Read the workflow or pre-commit hook before describing it; do not rely on memory.
2. Classify the ref or tool involved: external action, internal `projectbluefin/*` reusable, schema validator, or local hook.
3. Apply the policy in this order: artifact-protecting CI gates first, agent-enforced process conventions second.
4. Run the lightest verification that matches the change (`pre-commit`, `actionlint`, or direct source inspection).
5. If the session uncovered a non-obvious CI trap, write it to [`ci-pitfalls.md`](ci-pitfalls.md) in the same change. If it's a shell authoring/testability pattern, write it to [`shell-scripts.md`](shell-scripts.md).

---

## Contents
- [AI commit attribution (convention, not CI-gated)](#ai-commit-attribution-convention-not-ci-gated)
- [pre-commit auto-fix hooks modify files and abort the commit](#pre-commit-auto-fix-hooks-modify-files-and-abort-the-commit)
- [SHA pinning policy](#sha-pinning-policy)
- [Floating-tag guard](#floating-tag-guard)
- [release-state.yaml schema validation](#release-stateyaml-schema-validation)
- [Skill drift detection](#skill-drift-detection)
- [Renovate OCI digest tracking](#renovate-oci-digest-tracking)
- [Trivy scan-image archive input](#trivy-scan-image-archive-input)
- [Multi-arch build matrix in build.yml](#multi-arch-build-matrix-in-buildyml)
- [Shellcheck in validate.yml](#shellcheck-in-validateyml)
- [Renovate versioned-binary tracking](#renovate-versioned-binary-tracking)
- [Common Rationalizations](#common-rationalizations)
- [Red Flags](#red-flags)
- [Verification](#verification)

> **See also:** [`ci-pitfalls.md`](ci-pitfalls.md) for incident-log entries (branch-from-target, consumer PR format, caller permissions starvation, workflow_run name matching, merge_group sarif, Renovate automerge, buildah storage, ruleset check names, app token scoping). [`shell-scripts.md`](shell-scripts.md) for shell authoring and testability patterns.

---

## AI commit attribution (convention, not CI-gated)

AI-authored commits should carry both trailers as a convention:

```
Assisted-by: Claude Sonnet 4.6 via pi
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

The `validate.yml` attribution check was removed — it is **not** a CI gate. A missing or single trailer does not block your PR. Including both trailers is the expected convention but will never cause `exit 1`.

Note: `pi`-authored commits use `Assisted-by: <Model> via pi`. The `Co-authored-by: Copilot` trailer is optional but conventional.

---

## pre-commit auto-fix hooks modify files and abort the commit

When a pre-commit hook fixes a file in place, treat that run as a **failed gate that also produced a patch**. The hook output typically ends with `Files were modified by this hook`, the commit does not proceed, and you must review + re-stage the modified files before retrying.

Typical loop:

```bash
pre-commit run --all-files
git diff -- docs/skills/ci-tooling.md   # or inspect all modified files
git add <fixed-files>
pre-commit run --all-files
```

Do **not** assume the original staged snapshot is still current after an auto-fix hook. Re-stage the files the hook touched, or the next commit attempt will either fail again or commit an older index state than the working tree.

---

## SHA pinning policy

**All third-party `uses:` references must be pinned to a full commit SHA with a version comment.** Floating tags (`@v4`, `@main`, `@latest`) are rejected by the pre-commit hook.

### Why

Floating tags are a supply chain attack vector. Any upstream action can be compromised and inject malicious code on the next workflow run without any change to your workflow file. SHA pins guarantee bit-for-bit reproducibility.

### The pattern

```yaml
# correct — full SHA + human-readable version comment
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4
uses: taiki-e/install-action@be26d15a6e9c3a1e0696f6f1f5e56b4e46d08c29 # v2.47.0

# rejected by pre-commit
uses: actions/checkout@v4
uses: actions/checkout@main
uses: taiki-e/install-action@latest
```

### How to find the SHA for an action

```bash
# look up the tag's SHA
gh api repos/{owner}/{action}/git/ref/tags/{version} --jq '.object.sha'

# example
gh api repos/actions/checkout/git/ref/tags/v4.2.2 --jq '.object.sha'
```

### How to update a pinned SHA

1. Look up the new tag's SHA (command above)
2. Update the `uses:` line: `@<new-sha> # <new-version>`
3. Renovate handles most updates automatically once pins are tracked

### Internal `projectbluefin/` refs — managed tags, not SHA pins

**All `projectbluefin/` internal workflow refs use managed floating tags (`@main` or `@v1`), not SHA pins.**

The `no-floating-action-tags` pre-commit hook exempts all `projectbluefin/` refs via a negative lookahead. External refs (`actions/`, `docker/`, `taiki-e/`, etc.) are still required to be SHA-pinned.

SHA-pinning internal `projectbluefin/` workflow refs causes a factory cascade: every commit to `projectbluefin/actions` requires manual SHA bumps in all consumers (common, bluefin, bluefin-lts, dakota). Worse, a stale pin silently broke when the pinned commit predated the called file's existence, emitting only `startup_failure: This run likely failed because of a workflow file issue` with no further diagnosis (June 2026, bonedigger#27). The failure mode is worse than the risk of managed-tag drift. See [`ci-pitfalls.md`](ci-pitfalls.md) for the full incident.

**Current state (post June 2026 cleanup):**

| Caller file | Repo(s) | Calls | Ref |
|---|---|---|---|
| `lifecycle-caller.yml` | common | `projectbluefin/actions/.github/workflows/lifecycle.yml` | `@main` |
| `bonedigger.yml` | bluefin, bluefin-lts, dakota | `projectbluefin/bonedigger/.github/workflows/lifecycle.yml` | `@v1` |
| `run-testsuite.yml` | bluefin, bluefin-lts, dakota | `projectbluefin/testsuite/.github/workflows/e2e.yml` | `@main` |

**Anti-pattern to avoid:** SHA-pinning `projectbluefin/actions` or `projectbluefin/bonedigger` workflow refs. When a SHA predates the file's existence in the repo, GitHub emits `startup_failure: This run likely failed because of a workflow file issue` with no further diagnosis. See [bonedigger#27](https://github.com/projectbluefin/bonedigger/issues/27).

**Trap: bad semver tags.** The `v1.1.0` tag in `projectbluefin/actions` was cut from commit `95dc404b` (May 31 2026), which predates `lifecycle.yml` being added to that repo (June 10). Anyone who pinned to `v1.1.0` got a broken caller. Always verify a tag commit actually contains the file you're calling before pinning to it. Use `v1` (the managed floating tag).

---

## Floating-tag guard

**Scope:** shared pre-commit hook active in `common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`. Parity work pending in other repos.

**Regex:** `uses:(?!.*projectbluefin/).*@(main|master|latest|v[0-9])`

The `no-floating-action-tags` hook blocks commits of workflow files containing floating `uses:` refs. It scans `.github/workflows/` YAML files. All `projectbluefin/` refs are exempted via negative lookahead — they use managed floating tags by design. All external refs are subject to the hook.

### If you narrow the exemption, include reusable-workflow subpaths

If the exemption is narrowed from `projectbluefin/.*` to specific internal repos (for example `actions|bonedigger`), the negative lookahead must allow an optional subpath before `@`:

```regex
uses:(?!.*projectbluefin\/(?:actions|bonedigger)(?:\/[^@]*)?@).*@(main|master|latest|v[0-9]+)\b
```

The key fragment is `(?:\/[^@]*)?`. Without it, reusable workflow refs such as `projectbluefin/actions/.github/workflows/lifecycle.yml@main` or `projectbluefin/bonedigger/.github/workflows/lifecycle.yml@v1` can be falsely matched as forbidden floating tags.

### What the floating-tag hook blocks

Third-party actions must be pinned to a full commit SHA with a human-readable version comment. These floating refs are rejected:

```yaml
uses: actions/checkout@v4
uses: actions/checkout@main
uses: taiki-e/install-action@latest
uses: projectbluefin/testsuite/.github/workflows/e2e.yml@main  # CORRECT — internal ref, exempt from the hook
```

### Repos with managed tags (exempt)

All `projectbluefin/` internal refs are exempt from the hook. Current usage:
- `projectbluefin/actions` — `@v1` (common, bluefin, bluefin-lts, dakota build workflows) or `@main` (lifecycle-caller)
- `projectbluefin/bonedigger` — `@v1` maintained by bonedigger release process
- `projectbluefin/testsuite` — `@main` (managed floating tag, same policy as all internal refs)

External actions (everything outside `projectbluefin/`) must use full SHA pins.

### Renovate vs pre-commit

These two protections do different jobs:

- **The pre-commit hook** prevents new floating tags from entering the codebase
- **Renovate** updates existing SHA pins automatically once they are tracked

Use both. The hook enforces that refs are pinned at commit time. Renovate keeps them fresh.

---

## release-state.yaml schema validation

`.github/release-state.yaml` should be validated with the `check-jsonschema` pre-commit hook against the shared schema in `projectbluefin/actions`.

### Pin both the hook and the schema source

Use an immutable hook revision **and** an immutable raw schema URL pinned to the `actions` commit that introduced the schema:

```yaml
- repo: https://github.com/python-jsonschema/check-jsonschema
  rev: <commit-sha> # <version>
  hooks:
    - id: check-jsonschema
      files: ^\.github/release-state\.yaml$
      args:
        - --schemafile
        - https://raw.githubusercontent.com/projectbluefin/actions/<commit-sha>/docs/schemas/release-state.schema.json
```

Pinning the raw URL to a commit avoids silent schema drift on the next pre-commit run if `actions/main` changes. The hook is file-scoped, so `pre-commit run --all-files` is a no-op in repos that do not currently carry `.github/release-state.yaml`.

---

## Skill drift detection

**`common` does not run `skill-drift.yml`.** Do not add it.

Reason: AGENTS.md policy — *"Process conventions are self-enforced by agents. Never implement a process convention as a CI gate."* Skill update discipline lives in the agentic review loop, not in CI exit codes. A PR that ships a valid OCI improvement without a skill-doc update should not be blocked.

Other projectbluefin repos (bluefin, dakota, knuckle) run their own `skill-drift.yml` — that is their choice. The rule above applies only to `common`.

**Workflow (other repos):** `skill-drift.yml` calls the reusable workflow `projectbluefin/actions/.github/workflows/skill-drift-check.yml` at a pinned commit SHA (so the local floating-tag guard does not reject the caller).

### Repo path mapping

| Repo | code-paths | skill-paths |
|---|---|---|
| common | `.github/workflows/**`, `system_files/**`, `Containerfile`, `Justfile` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| bluefin | `.github/workflows/**`, `build_files/**`, `Justfile`, `recipes/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| bluefin-lts | `.github/workflows/**`, `build_files/**`, `Justfile` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| dakota | `.github/workflows/**`, `build_files/**`, `Justfile`, `elements/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| knuckle | `.github/workflows/**`, `cmd/**`, `internal/**`, `Justfile`, `scripts/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| testsuite | `.github/workflows/**`, `.github/actions/**`, `tests/**`, `scripts/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |

### When it fires

A PR that touches any repo's `code-paths` without also touching one of its `skill-paths` triggers the check. Currently advisory (warns but does not block merge) — treat as a hard requirement.

Full path-to-skill mapping and waiver process: [`skill-drift.md`](./skill-drift.md)

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

> **See also:** [`shell-scripts.md`](shell-scripts.md) for shellcheck directive pitfalls (SC1072/SC1073 inline notes, SC2086 quoting fixes, SC1091 suppression patterns in test contexts).

---

## Renovate versioned-binary tracking

`.github/renovate.json5` tracks versioned binaries downloaded in the build stage via custom regex managers:

| Binary | Source | Renovate pattern |
|---|---|---|
| `bonedigger` | `projectbluefin/bonedigger` GitHub releases | `BONEDIGGER_VERSION` in `system_files/bluefin/usr/share/ublue-os/just/60-bonedigger.just` |

When adding a new binary pinned to a specific version in a script or just file, add a corresponding regex manager entry in `renovate.json5` so the version stays current automatically.

---

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "pre-commit fixed it, so the commit probably succeeded." | Auto-fix hooks modify files **and fail the run**; re-stage the files and rerun the hooks. |
| "The regex already exempts `projectbluefin/actions`; subpaths will work too." | Reusable workflows add `/.github/workflows/...` before `@`; without an optional subpath, pygrep rules can still flag them. |
| "This is only a process convention, so CI details are not worth documenting." | Factory CI policy is shared infrastructure; undocumented traps get rediscovered across multiple repos. |
| "I know what this workflow publishes." | Read the workflow file. Project-internal CI facts drift faster than model memory. |

## Red Flags

- A commit fails with `Files were modified by this hook` and you retry without `git add`-ing the changed files
- A local floating-tag hook suddenly starts flagging internal reusable workflow refs
- A doc about CI policy describes current workflow behavior without quoting or deriving it from source
- A silent `startup_failure` is attributed to "GitHub being flaky" without checking caller `permissions:` or branch-from-target → see [`ci-pitfalls.md`](ci-pitfalls.md)

## Verification

- [ ] Read the workflow or hook being documented, not a secondary doc
- [ ] If pre-commit modified files, review the diff and re-stage them before retrying
- [ ] For `.github/workflows/` changes, run `pre-commit run --all-files` and `actionlint .github/workflows/*.yml`
- [ ] For doc-only CI skill updates, verify the examples and regexes against the current repo files they describe
- [ ] If a named tool's behavior matters (for example `pre-commit`, `trivy`, `shellcheck`), verify it against Context7 and record the library ID in frontmatter
- [ ] If the trap belongs in the incident log, put it in [`ci-pitfalls.md`](ci-pitfalls.md), not here
- [ ] If the pattern is about shell authoring or testability, put it in [`shell-scripts.md`](shell-scripts.md), not here
