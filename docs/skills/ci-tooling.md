---
name: ci-tooling
version: "1.0"
last_updated: 2026-06-23
tags: [ci, workflows, github-actions]
description: "Pre-commit floating-tag guard, SHA pinning policy, skill-drift workflow, and Renovate OCI digest tracking for projectbluefin repos. Use when editing .github/workflows/ files, enforcing SHA pinning, or understanding pre-commit policy guards."
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

## When to Use

- Editing `.github/workflows/` or `.pre-commit-config.yaml`
- Debugging pre-commit failures around floating tags, auto-fix hooks, or schema validation
- Updating shared CI policy that propagates across factory repos
- Auditing whether a workflow change belongs in repo-local CI or `projectbluefin/actions`

## When NOT to Use

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
5. If the session uncovered a non-obvious CI trap, write it back here in the same change.

---

## Contents
- [When to Use](#when-to-use)
- [When NOT to Use](#when-not-to-use)
- [Core Process](#core-process)
- [AI commit attribution (mandatory)](#ai-commit-attribution-mandatory)
- [pre-commit auto-fix hooks modify files and abort the commit](#pre-commit-auto-fix-hooks-modify-files-and-abort-the-commit)
- [SHA pinning policy](#sha-pinning-policy)
- [Floating-tag guard](#floating-tag-guard)
- [Skill drift detection](#skill-drift-detection)
- [Renovate OCI digest tracking](#renovate-oci-digest-tracking)
- [Renovate versioned-binary tracking](#renovate-versioned-binary-tracking)
- [Bulk SHA bump — regex multiline trap](#bulk-sha-bump--regex-multiline-trap)
- [projectbluefin/actions PR — consumer validation evidence](#projectbluefinactions-pr--consumer-validation-evidence)

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

SHA-pinning internal `projectbluefin/` workflow refs causes a factory cascade: every commit to `projectbluefin/actions` requires manual SHA bumps in all consumers (common, bluefin, bluefin-lts, dakota). Worse, a stale pin silently broke when the pinned commit predated the called file's existence, emitting only `startup_failure: This run likely failed because of a workflow file issue` with no further diagnosis (June 2026, bonedigger#27). The failure mode is worse than the risk of managed-tag drift.

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

---

## Renovate versioned-binary tracking

`.github/renovate.json5` tracks versioned binaries downloaded in the build stage via custom regex managers:

| Binary | Source | Renovate pattern |
|---|---|---|
| `bonedigger` | `projectbluefin/bonedigger` GitHub releases | `BONEDIGGER_VERSION` in `system_files/bluefin/usr/share/ublue-os/just/60-bonedigger.just` |

When adding a new binary pinned to a specific version in a script or just file, add a corresponding regex manager entry in `renovate.json5` so the version stays current automatically.

---

## Removing a shell script from common — 4 mandatory touch-points

When deleting `system_files/bluefin/usr/bin/<script>`, check all four:

| File | What to remove |
|---|---|
| `.github/workflows/unit-tests.yml` | The script path from the shellcheck `run:` block |
| `.github/workflows/validate.yml` | The `shellcheck` step that invokes it (if script-specific) **and** any `candidates.append(Path("..."))` entry in the Python OCI-ref guard |
| `system_files/bluefin/usr/share/ublue-os/just/system.just` | The `just` target and all aliases |
| `docs/skills/` | The script's skill file (if it has one) + its `INDEX.md` row + `SKILL.md` routing row + all cross-references |

### Dead apt step hazard

If the `validate.yml` shellcheck step was the **only** consumer of `Install shellcheck` in that job, delete the apt install step too — it becomes a silent no-op that wastes ~20 seconds per CI run and confuses future readers.

### Cross-reference sweep

After deleting the script and its skill file, run:
```bash
grep -rn "<script-name>" docs/ specs/ --include="*.md" --include="*.json"
```
Common survivors: `devmode.md` advisories, `image-registry.md` section headers, `specs/` JSON chunks.

## Shell Script Testability Patterns

### pytest-cov: `--cov=tests` measures the wrong thing

`--cov=tests` reports coverage of the test files themselves — always ~100% trivially.
It does **not** measure the source code under test.

For `hooks.py` loaded via `importlib.util.spec_from_file_location`, use the source directory:

```yaml
# WRONG — measures tests/test_hooks.py, not hooks.py
python3 -m pytest tests/test_hooks.py --cov=tests --cov-fail-under=80

# CORRECT — measures system_files/bluefin/etc/bazaar/hooks.py
python3 -m pytest tests/test_hooks.py --cov=system_files/bluefin/etc/bazaar --cov-fail-under=80
```

---

### flock FD ordering — mkdir-p must precede the subshell

`(...) 200>"${lock_file}"` opens the FD **before** the subshell body executes.
On first boot when the parent directory doesn't exist, the redirect fails before
flock runs — every caller exits non-zero and silently skips.

```bash
# WRONG — mkdir runs too late; redirect fails if dir missing
(
    flock -x 200
    mkdir -p "$(dirname "${FILE}")"
    ...
) 200>"${lock_file}"

# CORRECT — directory exists before the FD is opened
mkdir -p "$(dirname "${FILE}")"
(
    flock -x 200
    ...
) 200>"${lock_file}"
```

**General rule:** any `>`/`>>` redirect must have its parent directory created before
the redirect expression, not inside the command body.

---

### stdin redirect testability — never hardcode the path

Scripts using `< /usr/share/ublue-os/image-info.json` fail in CI because the
file doesn't exist on runners. The shell fails the redirect **before** jq runs.
A jq PATH-stub mock won't help — jq never gets called.

```bash
# WRONG — fails in CI; variable is always empty
TAG="$(jq -r '."image-tag"' < /usr/share/ublue-os/image-info.json)"

# CORRECT — env-var override allows test isolation
IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
TAG="$(jq -r '."image-tag"' < "${IMAGE_INFO_FILE}")"
```

In bats `setup()`: create `${WORKDIR}/image-info.json` and `export IMAGE_INFO_FILE`.
Apply to any script reading system files via stdin redirect.

---

### Assert env-var export against the subshell consumer, not exec

`exec` inherits all shell variables whether exported or not — asserting `DEFAULT_THEME`
in the exec'd process always passes even with `export` removed.

`$(ublue-bling-fastfetch)` runs in a **subshell** — subshells inherit only **exported**
variables. This is the consumer to instrument.

```bash
# WRONG — passes even without export keyword
printf '#!/bin/bash\necho "VAR=${VAR}"\n' > mock-fastfetch

# CORRECT — fails if export is removed (subshell can't see unexported vars)
printf '#!/bin/bash\necho "VAR=${VAR}"\necho "blue"\n' > mock-ublue-bling-fastfetch
```

**Rule:** identify the actual consumer (the `$(...)` call) and instrument that mock.

---


Wrap the main flow so sourcing the script in bats only loads functions:
```bash
# Functions at top — always loadable
get_uuid() { ... }
check_device() { ... }

# Main flow only runs when executed directly, not when sourced for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gum confirm ...
fi
```
When bats runs `source "${SCRIPT}"`, `$0` is the bats runner, so the guard evaluates false and only functions load.

### Testability env-var override idiom

Use the `${VAR:-default}` idiom for any path the script reads from `/proc` or `/dev`:
```bash
CMDLINE_FILE="${CMDLINE_FILE:-/proc/cmdline}"
SETUP_CONFIG_FILE="${SETUP_CONFIG_FILE:-/etc/ublue-os/setup.json}"
```
Tests export the override before running: `export CMDLINE_FILE="${WORKDIR}/cmdline"`.
Used in: `luks-tpm2-autounlock` (CMDLINE_FILE, DISK_BY_UUID_DIR, DEV_DIR), `ublue-*-setup` (SETUP_CONFIG_FILE), `ublue-bling` (BLING_CLI_DIRECTORY, BLING_ENV_SCRIPT).

### PATH-stub mocking for interactive commands

```bash
setup() {
    mkdir -p "${WORKDIR}/bin"
    printf '#!/bin/bash\nexit 0\n' > "${WORKDIR}/bin/gum"   # always confirm
    chmod +x "${WORKDIR}/bin/gum"
    # Record args for assertion:
    printf '#!/bin/bash\necho "$*" >> %s/calls.log\nexit 0\n' "${WORKDIR}" \
        > "${WORKDIR}/bin/systemd-cryptenroll"
    chmod +x "${WORKDIR}/bin/systemd-cryptenroll"
    export PATH="${WORKDIR}/bin:${PATH}"
}
```
Used for `gum`, `systemd-cryptenroll`, `bootc`, `rpm-ostree`. Check `"${WORKDIR}/calls.log"` in assertions.

### Shellcheck pitfalls

**Disable comment — no inline notes (SC1072/SC1073):**
```bash
# WRONG:
# shellcheck disable=SC2086 -- SET_PIN_ARG intentionally unquoted
# CORRECT — directive alone on its own line:
# shellcheck disable=SC2086
sudo cmd ${OPTIONAL_ARG} "${REQUIRED_ARG}"
```

**Profile.d scripts without shebangs (SC2148):**
```bash
# shellcheck shell=bash
alias neofetch='ublue-fastfetch'
```

**Suppress SC1091 (source-following info) for the find step:**
```yaml
- name: Run shellcheck — .sh scripts
  run: find system_files -name '*.sh' -print0 | xargs -0 shellcheck -e SC1091
```

### Both quoting fixes required for hook runners

When fixing `bash $script` (SC2086), also quote the directory in the for loop:
```bash
# WRONG — word-splits on directory path AND script variable:
for script in $HOOKS_DIR/* ; do
    bash $script
done

# CORRECT — both must be quoted:
for script in "${HOOKS_DIR}"/* ; do
    bash "$script"
done
```
A space in `HOOKS_DIR` will silently fail to find hooks if only `$script` is fixed.

### Subagent factual claims need source verification

Architecture documents from subagents must be source-verified before committing.
Subagents have hallucinated file content and CI config state. Always `grep` the
actual file before accepting a claim about its contents or existence.

### XDG_CONFIG_HOME isolation in bats tests

GitHub Actions runners set `XDG_CONFIG_HOME=/home/runner/.config` in their environment. If a bats test overrides `HOME` to a temp dir but does not clear `XDG_CONFIG_HOME`, any script using `${XDG_CONFIG_HOME:-$HOME/.config}` will write to the **real runner path**, not the test's isolated temp dir.

The directory `/home/runner/.config/fish` does not exist on runners, so `cat >>` or similar fails, and with `set -e` the script exits non-zero — test reports `status != 0` with no other diagnostic output.

**Fix:** add `unset XDG_CONFIG_HOME` in `setup()` alongside `export HOME=...`:
```bash
setup() {
    WORKDIR="$(mktemp -d)"
    export HOME="${WORKDIR}/home"
    unset XDG_CONFIG_HOME   # CI runner sets this; prevent it leaking into subprocess
    mkdir -p "${HOME}"
    ...
}
```
This ensures scripts fall back to `$HOME/.config` which is the test's temp dir.

### `gh run rerun` uses the original commit SHA, not current HEAD

`gh run rerun <run-id>` replays the workflow on the commit that originally triggered it. If you have since force-pushed the branch, the rerun still tests the old commit.

To trigger CI on the **current** HEAD after a force push:

```bash
# Option 1 — push a new commit (even empty)
git commit --allow-empty -m "ci: trigger fresh CI run" && git push origin <branch>

# Option 2 — manually dispatch the workflow on the branch
gh workflow run unit-tests.yml --repo projectbluefin/common --ref <branch>

# Option 3 — cancel the stale in-progress run, then push
gh run cancel <run-id> --repo projectbluefin/common
```

If a stale in-progress run with `cancel-in-progress: true` is blocking new triggers, cancel it explicitly — the new push may have silently been queued but not started.

---

## ⛔ Branch-from-target rule (merge queue repos)

Every projectbluefin repo runs a merge queue. A PR with merge conflicts or a dirty diff **cannot enter the queue** and stalls work for everyone on that branch.

**Root cause of dirty diffs:** Creating a branch from `main` when the PR targets `testing`. The `testing` branch in `bluefin`, `bluefin-lts`, and `dakota` accumulates CI and release-pipeline commits that never land on `main`. A branch created from `main` is missing those commits — the PR diff shows them all as "deleted".

### Branch targets

| Repo | PR targets | Branch FROM |
|---|---|---|
| `bluefin`, `bluefin-lts`, `dakota` | `testing` | `testing` |
| `common`, `actions`, `knuckle` | `main` | `main` |

### Mandatory pre-open gate (every PR)

```bash
TARGET=testing   # or main — match the PR target
git fetch origin

# 1. Only your files in the diff
git diff --name-only origin/${TARGET}..HEAD
# If unintended files appear → wrong base. Recreate from origin/${TARGET}.

# 2. No merge conflicts
git merge --no-commit --no-ff origin/${TARGET}
git merge --abort 2>/dev/null || true

# 3. No known red CI
# Do not open a PR if local tests fail. The merge queue will reject it.
just check && pre-commit run --all-files
```

### Recreating a branch with the wrong base

```bash
# Identify your commits
git log --oneline origin/${TARGET}..HEAD

# Recreate from the correct base
git checkout -b <branch>-clean origin/${TARGET}
git cherry-pick <your-sha1> <your-sha2> ...
```

*Observed violation: `projectbluefin/dakota` PR was created from `main` targeting `testing`. The `testing` branch had 20+ diverged commits — 12 workflow files, Justfile changes, and BST element updates all appeared as "deleted" in the diff. PR closed; clean PR recreated from `testing`.*

---

## Bulk SHA bump — regex multiline trap

When scripting a bulk `projectbluefin/actions` SHA pin update across workflow files, Python's `[^@]*` character class matches newlines. If the regex is `(projectbluefin/actions[^@]*)@([a-f0-9]{40})`, a line containing `projectbluefin/actions` in a **comment** (no `@` sign) will extend the match across subsequent lines until the next `@`, inadvertently replacing the SHA of unrelated actions (e.g., `actions/checkout`).

**Safe approach — line-scoped replacement:**

```python
import re

def bump_sha(content: str, new_sha: str) -> str:
    lines = content.splitlines(keepends=True)
    result = []
    for line in lines:
        # Only replace if projectbluefin/actions is on THIS line
        if 'projectbluefin/actions' in line:
            line = re.sub(
                r'(projectbluefin/actions[^@\n]*)@([a-f0-9]{40})',
                rf'\g<1>@{new_sha}',
                line,
            )
        result.append(line)
    return ''.join(result)
```

Key difference: `[^@\n]*` (excludes newline) instead of `[^@]*`.

**Verify after any bulk bump:**

```bash
# Find lines using the new SHA that are NOT from projectbluefin/actions
grep -rn "$NEW_SHA" .github/workflows/ | grep -v 'projectbluefin/actions'
```

If any non-`projectbluefin/actions` lines appear, restore their original SHAs.

---

## projectbluefin/actions PR — consumer validation evidence

Any PR to `projectbluefin/actions` that modifies an action or reusable workflow (`reusable-*.yml`, composite action `action.yml`) triggers the **Consumer Validation** CI check. The PR body must contain exactly these three lines:

```
Consumer PR: https://github.com/projectbluefin/{bluefin|bluefin-lts|dakota}/pull/{N}
Consumer CI run: https://github.com/projectbluefin/{repo}/actions/runs/{N}
Out-of-org consumer impact: {explanation or "N/A"}
```

### ⛔ Consumer PR body format — colon syntax is REQUIRED

The `check-consumer-contract.yml` regex matches `^Consumer PR:` **literally** (colon, no space before colon, space after). Using a Markdown heading silently fails:

```markdown
# WRONG — regex does not match a heading; check silently fails
## Consumer PR
https://github.com/projectbluefin/bluefin/pull/N

# CORRECT — colon format on one line
Consumer PR: https://github.com/projectbluefin/bluefin/pull/N
Consumer CI run: https://github.com/projectbluefin/bluefin/actions/runs/N
```

Same rule applies to `Consumer CI run:`. The CI run URL must point to a **passing** run in the consumer repo (bluefin, bluefin-lts, or dakota) that exercises the changed action.

---

## Caller-level permissions starvation

When a workflow calls a reusable workflow, the **caller's `permissions:` block is the maximum grant**. A reusable job that declares `permissions: contents: write` cannot exceed what the caller grants — it silently receives only `read`.

```yaml
# WRONG — caller grants only read; reusable's write permission is silently downgraded
jobs:
  call:
    permissions:
      contents: read
    uses: projectbluefin/actions/.github/workflows/reusable-promote.yml@<sha>

# CORRECT — caller grants the union of all permissions the reusable jobs need
jobs:
  call:
    permissions:
      contents: write
      packages: write
      id-token: write
      attestations: write
    uses: projectbluefin/actions/.github/workflows/reusable-promote.yml@<sha>
```

**Symptom:** The reusable job shows `startup_failure` with no further error output. Check the caller's `permissions:` block first — it is the most common root cause.

*Observed: caused `startup_failure` on every bluefin-lts promote push until fixed in bluefin-lts #162.*

---

## workflow_run trigger — exact workflow name matching

`workflow_run` triggers match on the **exact `name:` field** of the target workflow YAML file, not the filename. If the name drifts between repos or variants, the trigger silently never fires.

```yaml
# WRONG — watches "Build Bluefin LTS" but the HWE image is built by "Build Bluefin LTS HWE"
on:
  workflow_run:
    workflows: ["Build Bluefin LTS"]
    types: [completed]

# CORRECT — watch the workflow that actually produces the artifact you're testing
on:
  workflow_run:
    workflows: ["Build Bluefin LTS HWE"]
    types: [completed]
```

**Diagnostic checklist:**
1. Open the target workflow YAML and read the top-level `name:` field
2. Confirm that workflow actually produces the artifact you're gating on
3. Check: does the triggering workflow run on the branch you expect?

*Observed: bluefin-lts post-merge-e2e was watching `Build Bluefin LTS` but testing the HWE image (produced by `Build Bluefin LTS HWE`) — gate always skipped. Fixed in bluefin-lts #163.*

- `Consumer PR`: link to a PR in a consuming repo that exercises the changed action (bluefin preferred)
- `Consumer CI run`: link to a passing Actions run in the consuming repo showing the change works
- `Out-of-org consumer impact`: explain whether aurora/bazzite are affected, or state `N/A` explicitly

Leaving these lines blank or using placeholder text (`TODO`, `TBD`, `<!-- ...-->`) fails the check. The CI error is: `Consumer validation evidence is required for action or reusable workflow changes. See docs/skills/consumer-validation.md.`

## merge_group + upload-sarif ref failure

`github/codeql-action/upload-sarif` fails for merge queue builds with:

```
##[error]ref 'refs/heads/gh-readonly-queue/main/pr-NNN-...' not found in this repository
```

The ephemeral `gh-readonly-queue/...` refs are not resolvable by `upload-sarif`. The PR Build already ran the scan; the merge queue build is redundant for CVE checking — its purpose is only to verify the combined commit builds cleanly.

**Fix:** Add `if: github.event_name != 'merge_group'` to both the export and scan steps:

```yaml
- name: Export image for scanning
  if: github.event_name != 'merge_group'
  ...

- name: Scan image for CVEs
  if: github.event_name != 'merge_group'
  ...
```

*Observed: blocked every PR in the merge queue until fixed in common #660.*

---

## Renovate automerge — how it works in `common`

`common` uses `platformAutomerge: true` in `renovate.json`. Renovate calls GitHub's native
auto-merge API when it opens an eligible PR (digest/pin/patch/minor). GitHub's auto-merge
enqueues the PR into the merge queue once all required checks pass — no separate workflow needed.

**Why `platformAutomerge` instead of a workflow:** `common/main` has a merge queue ruleset.
`github-actions[bot]` cannot bypass the merge queue, so any workflow attempting a direct
`--squash` merge would fail. `platformAutomerge` avoids this: Renovate is a bypass actor in the
PR review ruleset (actor_id 2740, bypass_mode: pull_request) and uses GitHub's own auto-merge
API, which the merge queue respects natively.

**Eligible update types:** `digest`, `pin`, `patch`, `minor`. Major bumps require human review.

**Bypass actors in the PR review ruleset:**
- OrganizationAdmin — `bypass_mode: always`
- Renovate (actor_id 2740) — `bypass_mode: pull_request`
- Mergeraptor (actor_id 3069633) — `bypass_mode: pull_request`

**Stuck Renovate PR (required checks passed but PR not merging):** Check that auto-merge is
enabled on the PR (`gh pr view <N> --json autoMergeRequest`). If null, Renovate hasn't enabled
it — check the `matchUpdateTypes` rule. If enabled but not merging, verify all required checks
(`validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)`) show SUCCESS or
SKIPPED. Org admin can force-merge via:
```bash
gh api repos/projectbluefin/common/pulls/<N>/merge -X PUT -f merge_method=squash
```

**`build.yml` paths-ignore and workflow-only Renovate PRs:** Renovate bumps GitHub Actions SHAs
via digest PRs that only change `.github/workflows/**`. The `pull_request` trigger in `build.yml`
intentionally does NOT ignore `.github/workflows/**` so required Build checks always run on these
PRs and the merge queue can satisfy them. The `push` trigger DOES ignore `.github/workflows/**`
to avoid redundant post-merge rebuilds.

---

## build.yml — rootless buildah vs root podman storage

`build.yml` uses `redhat-actions/buildah-build` which stores images in **rootless user storage** (`~/.local/share/containers`). The `push-image` composite action uses `sudo podman push` which reads **root storage** (`/var/lib/containers`). These are different namespaces — the push will fail with `image not known` if the image is not in root storage.

**Fix already in place:** After `Export image for scanning`, a `sudo skopeo copy` step promotes the docker-archive into root `containers-storage` so `push-image` finds it.

```yaml
- name: Promote image to root storage for push
  if: github.event_name != 'pull_request'
  shell: bash
  run: |
    sudo skopeo copy \
      "docker-archive:/tmp/scan-image.tar:${{ env.IMAGE_NAME }}:${{ steps.generate-tags.outputs.local_tag }}" \
      "containers-storage:${{ env.IMAGE_NAME }}:${{ steps.generate-tags.outputs.local_tag }}"
```

Do not remove this step. Without it every push-to-GHCR fails silently until the next build.

---

## build.yml — GHCR login required before cosign signing

The `sign-and-publish` composite action's internal step order is: cosign sign (step 5) → ORAS registry login (step 12). Cosign has no GHCR credentials at step 5 and fails UNAUTHORIZED when pushing the signature blob.

**Fix already in place:** A `docker/login-action` step runs immediately before `sign-and-publish` in the manifest job.

Do not remove this step or reorder it after sign-and-publish.

---

## renovate-automerge.yml — merge queue on main requires --auto, not direct merge

`common/main` has a **merge queue ruleset** (`main — merge queue`). `github-actions[bot]` is not a bypass actor for that ruleset. Calling `gh pr merge --squash` directly is rejected with:

```
The merge strategy for main is set by the merge queue
```

The reusable `reusable-renovate-automerge.yml` uses direct `--squash` merge (correct for `testing` branches which have no merge queue). Do **not** use it for `common`. The caller `renovate-automerge.yml` is intentionally inlined and uses `--auto --squash` to enqueue the PR. Since the workflow fires after a successful build, checks have already passed and the queue processes immediately.

**Symptom when broken:** The automerge workflow logs show `✅ Merged PR #N` but the PR remains open. The `||` catch in the merge command suppresses the real error; the success echo runs unconditionally after it.

**Fix already in place:** `renovate-automerge.yml` inlines the PR-find + enqueue logic with `gh pr merge --auto --squash` (PR #782). The reusable is not used here.

Do not "simplify" this back to the reusable — it will silently break again.

## Ruleset required status check names must match exact CI job names

The two branch rulesets on `main` must use the **exact** job names from `build.yml`. Wrong names silently block the merge queue — checks never arrive, queue waits forever.

Correct names (as of 2026-06-22):

| Ruleset | Required checks |
|---|---|
| `main — merge queue` (ID 17513003) | `validate`, `Build and push image (x86_64)`, `Build and push image (aarch64)` |
| `main-review-required-with-renovate-bypass` (ID 17070417) | *(no required status checks — bypass actors cover Renovate/mergeraptor; merge queue ruleset handles build gate)* |

**Past breakage:** ruleset 17070417 had `"Build and push image"` (no arch suffix) — never matched any actual check, blocked every Renovate PR. Fixed 2026-06-22 by removing the check entirely from the review ruleset and using correct names in the merge queue ruleset.

If `build.yml` job names change, update both rulesets immediately via:
```bash
gh api --method PUT repos/projectbluefin/common/rulesets/17513003 --input ruleset.json
```

---

## create-github-app-token — do not use `owner` + `repositories` for cross-repo scoping

`create-github-app-token@v3` fails with `Invalid keyData` when `owner: <org>` + `repositories: <other-repos>` are specified. The action attempts cross-installation token creation which does not work reliably with this key format.

**Pattern to avoid:**
```yaml
uses: actions/create-github-app-token@...
with:
  owner: projectbluefin
  repositories: bluefin,bluefin-lts,dakota  # breaks
```

Use the token without `owner`/`repositories` restrictions — the mergeraptor app is installed org-wide and the default token already has access.

### notify-downstream token in common/build.yml

The `notify-downstream` job in `build.yml` uses `secrets.MERGERAPTOR_APP_ID` + `secrets.MERGERAPTOR_PRIVATE_KEY`. These secrets must be accessible to the `common` repo. If they are not, the job fails with:

```
The 'client-id' (or deprecated 'app-id') input must be set to a non-empty string.
```

Note: `vars.MERGERAPTOR_APP_ID` (variable, not secret) does **not** resolve in common — do not use it here. The correct ref is `secrets.MERGERAPTOR_APP_ID`. Verify at:
https://github.com/organizations/projectbluefin/settings/secrets/actions

The job has `continue-on-error: true` — build stays green while dispatches fail. Downstream tracking falls back to Renovate (bluefin/bluefin-lts) and dakota's daily cron.

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
- A PR targets `testing` but the branch was created from `main`
- A doc about CI policy describes current workflow behavior without quoting or deriving it from source

## Verification

- [ ] Read the workflow or hook being documented, not a secondary doc
- [ ] If pre-commit modified files, review the diff and re-stage them before retrying
- [ ] For `.github/workflows/` changes, run `pre-commit run --all-files` and `actionlint .github/workflows/*.yml`
- [ ] For doc-only CI skill updates, verify the examples and regexes against the current repo files they describe
- [ ] If a named tool's behavior matters (for example `pre-commit`), verify it against Context7 and record the library ID in frontmatter
