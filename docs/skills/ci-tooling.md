---
name: ci-tooling
description: "Pre-commit floating-tag guard, SHA pinning policy, skill-drift workflow, and Renovate OCI digest tracking for projectbluefin repos. Use when editing .github/workflows/ files, enforcing SHA pinning, or understanding pre-commit policy guards."
metadata:
  type: procedure
---

# CI tooling

## Contents
- [AI commit attribution (mandatory)](#ai-commit-attribution-mandatory)
- [SHA pinning policy](#sha-pinning-policy)
- [Floating-tag guard](#floating-tag-guard)
- [Skill drift detection](#skill-drift-detection) *(removed from common — agentic enforcement only)*
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

### Internal `projectbluefin/` refs — different policy

Internal reusable workflow refs use a coordinated policy, not blanket SHA pinning:

- `lifecycle-caller.yml` files pin `projectbluefin/common/.github/workflows/lifecycle.yml@<SHA>` — Renovate manages those SHA updates
- The old `projectbluefin/bonedigger/.github/workflows/lifecycle.yml@main` exemption was retired when lifecycle ownership moved into `common`
- Other internal `projectbluefin/` refs follow repo-local policy comments — read the comment before converting
- Coordinate with maintainers before changing an internal ref policy

---

## Floating-tag guard

**Scope:** shared pre-commit hook active in `common`, `bluefin`, `bluefin-lts`, `dakota`, `actions`. Parity work pending in other repos.

**Regex:** `uses:(?!.*projectbluefin/).*@(main|master|latest|v[0-9])`

The `no-floating-action-tags` hook blocks commits of workflow files containing floating `uses:` refs. It scans `.github/workflows/` YAML files. Internal `projectbluefin/` refs are explicitly exempted via the negative lookahead — `@main` on `projectbluefin/actions` reusable workflows is intentional.

### What it blocks

Third-party actions must be pinned to a full commit SHA with a human-readable version comment. These floating refs are rejected:

```yaml
uses: actions/checkout@v4
uses: actions/checkout@main
uses: taiki-e/install-action@latest
```

### Managed `projectbluefin/` refs

The ACMM audit treats some internal reusable workflows as a documented policy exception, not a lint cleanup target. `projectbluefin/` internal reusable workflows should follow the repo-local policy comments rather than blanket float-to-`@main` cleanup.

### Renovate vs pre-commit

These two protections do different jobs:

- **The pre-commit hook** prevents new floating tags from entering the codebase
- **Renovate** updates existing SHA pins automatically once they are tracked

Use both. The hook enforces that refs are pinned at commit time. Renovate keeps them fresh.

---

## Skill drift detection

> **`common` removed `skill-drift.yml` in [PR #569](https://github.com/projectbluefin/common/pull/569).** Reason: AGENTS.md policy — *"Process conventions are self-enforced by agents. Never implement a process convention as a CI gate."* The gate caused spurious CI failures on valid OCI PRs that omitted a doc update. Skill update discipline is enforced in the agentic review loop and in AGENTS.md, not by CI exit 1.
>
> Other projectbluefin repos (bluefin, dakota, knuckle) still run their own `skill-drift.yml` — that's their choice per repo. Do not re-add it to `common`.

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
2. `ghcr.io/projectbluefin/bluefin-wallpapers-gnome:latest@sha256:...` via a custom regex manager in `.github/renovate.json5`

### Why both managers exist

- `FROM docker.io/library/alpine:latest@sha256:...` is a standard Dockerfile dependency — the built-in `dockerfile` manager handles it
- `COPY --from=ghcr.io/projectbluefin/bluefin-wallpapers-gnome:latest@sha256:...` is not covered by the default parser — a custom regex manager tracks it

### Rule when adding OCI pins

If you add new OCI image pins to `Containerfile`, also update `.github/renovate.json5` so Renovate can keep them current. Applies to both `FROM` and `COPY --from=` references. An untracked pin silently goes stale.

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
Common survivors: `devmode.md` advisories, `image-registry.md` section headers, `acmm-audit-level2.md` risk statements, `specs/` JSON chunks.

## Shell Script Testability Patterns (added 2026-06-10)

### BASH_SOURCE guard for interactive scripts

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

- `Consumer PR`: link to a PR in a consuming repo that exercises the changed action (bluefin preferred)
- `Consumer CI run`: link to a passing Actions run in the consuming repo showing the change works
- `Out-of-org consumer impact`: explain whether aurora/bazzite are affected, or state `N/A` explicitly

Leaving these lines blank or using placeholder text (`TODO`, `TBD`, `<!-- ...-->`) fails the check. The CI error is: `Consumer validation evidence is required for action or reusable workflow changes. See docs/skills/consumer-validation.md.`
