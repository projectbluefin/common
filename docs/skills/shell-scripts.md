---
name: shell-scripts
version: "1.0"
last_updated: 2026-06-24
tags: [shell, bash, testing, bats, shellcheck]
description: "Shell script authoring and testability in common — removing a shell script (4 touch-points), bats mocking patterns, env-var override idioms, PATH-stub mocking, shellcheck pitfalls, XDG isolation, idempotent main guard. Use when writing or testing shell scripts under system_files/."
metadata:
  type: reference
  context7-sources:
    - /koalaman/shellcheck
    - /bats-core/bats-core
---

# Shell Scripts — authoring and testability

> Split from [`ci-tooling.md`](ci-tooling.md) on 2026-06-24. This file holds shell script authoring patterns, testability idioms, and the mandatory touch-points when removing a script. [`ci-tooling.md`](ci-tooling.md) retains CI policy and config; [`ci-pitfalls.md`](ci-pitfalls.md) retains the incident log.

<!-- TODO(context7): verify shellcheck directive syntax (SC1072/SC1073, SC1091, SC2148, SC2207) and bats setup/teardown semantics against upstream docs. These were documented from live test debugging, not from Context7 lookups. -->

## When to Use

- Writing or modifying a shell script under `system_files/`
- Writing bats tests for a shell script
- Debugging a shellcheck failure in validate.yml
- Removing a shell script from common (the 4 mandatory touch-points)

## When NOT to Use

- CI workflow configuration (pre-commit, actionlint, SHA pinning) → [`ci-tooling.md`](ci-tooling.md)
- CI incident log and silent failure patterns → [`ci-pitfalls.md`](ci-pitfalls.md)

---

## Contents
- [Removing a shell script from common — 4 mandatory touch-points](#removing-a-shell-script-from-common--4-mandatory-touch-points)
- [Shell Script Testability Patterns](#shell-script-testability-patterns)
  - [pytest-cov: --cov=tests measures the wrong thing](#pytest-cov---covtests-measures-the-wrong-thing)
  - [flock FD ordering — mkdir-p must precede the subshell](#flock-fd-ordering--mkdir-p-must-precede-the-subshell)
  - [stdin redirect testability — never hardcode the path](#stdin-redirect-testability--never-hardcode-the-path)
  - [Assert env-var export against the subshell consumer, not exec](#assert-env-var-export-against-the-subshell-consumer-not-exec)
  - [Idempotent main guard](#idempotent-main-guard)
  - [Testability env-var override idiom](#testability-env-var-override-idiom)
  - [PATH-stub mocking for interactive commands](#path-stub-mocking-for-interactive-commands)
  - [Shellcheck pitfalls](#shellcheck-pitfalls)
  - [Both quoting fixes required for hook runners](#both-quoting-fixes-required-for-hook-runners)
  - [Subagent factual claims need source verification](#subagent-factual-claims-need-source-verification)
  - [XDG_CONFIG_HOME isolation in bats tests](#xdg_config_home-isolation-in-bats-tests)
  - [gh run rerun uses the original commit SHA, not current HEAD](#gh-run-rerun-uses-the-original-commit-sha-not-current-head)
- [Red Flags](#red-flags)
- [Verification](#verification)

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

---

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

### Idempotent main guard

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

<!-- TODO(context7): verify all shellcheck SC codes and directive syntax against shellcheck docs -->

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

<!-- TODO(context7): verify XDG_CONFIG_HOME fallback behavior and precedence against freedesktop.org spec docs -->

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

## Red Flags

- A shell script reads from a hardcoded `/proc`, `/dev`, or `/usr/share/...` path without an env-var override — untestable in CI
- A bats test overrides `HOME` but not `XDG_CONFIG_HOME` — leaks to the real runner config dir
- A shellcheck `disable=` directive has an inline comment after it (SC1072/SC1073)
- A script's main flow runs on `source` (no `BASH_SOURCE` guard) — breaks bats loading
- `--cov=tests` in a pytest invocation — measures test files, not source under test

---

## Verification

- [ ] `shellcheck -S warning <file>` passes on the modified script
- [ ] `just test` passes locally (bats + pytest)
- [ ] If a shellcheck directive was added, verify its syntax against Context7 (shellcheck library) and confirm the SC code is correct
- [ ] If a bats test uses env-var overrides, confirm the script uses `${VAR:-default}` at the read site — the override does nothing without it
- [ ] If a script was removed, all 4 touch-points were checked and the cross-reference sweep returned no survivors
