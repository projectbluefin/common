# Shell Script Testability Patterns

Part of [shell-scripts](../SKILL.md) — full WRONG/CORRECT code examples for every testability idiom used in common's shell scripts.

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

### Guard optional runtime commands before doing work

A shared wrapper may be copied into images whose package set does not include the
command it delegates to. Check the executable before reading configuration or
invoking helper commands so the wrapper remains a harmless no-op in those
consumers:

```bash
if ! command -v fastfetch >/dev/null 2>&1; then
    exit 0
fi
```

Test the missing-command path with a restricted `PATH` and assert both a zero
status and that the delegated command was not invoked. Keep the normal path
covered separately with a PATH stub for the delegated executable.

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

### Docs skill validators need synthetic trees

Scripts that validate `docs/skills/` or `docs/SKILL.md` should run from a temp
cwd with a handcrafted mini catalog. The real repo tree is too large for clean
negative tests, and a synthetic tree keeps link, front-matter, and index
failures deterministic.

For `generate_skill_index.py`, patch `REPO_ROOT`, `SKILLS_DIR`, `SCHEMA_PATH`,
and `INDEX_PATH` to point at the fixture tree before calling `build_catalog()`
or `main()`. This keeps `--write` and `--check` safe in unit tests without
touching the live repo files.

### Test retired delegation with a failing stub

Native recipes must work even when a retired delegate remains installed.
Put a failing stub ahead of host commands in `PATH`, rather than hiding a
particular installation directory:

```bash
printf '#!/bin/bash\necho "unexpected bctl invocation" >&2\nexit 99\n' > "${MOCKDIR}/bctl"
chmod +x "${MOCKDIR}/bctl"
export PATH="${MOCKDIR}:${PATH}"
```

The update and changelog suites use this to prove that an installed `bctl`
cannot take over the recipe. Mock all remaining side-effecting commands and
assert their calls as well as the exit status. Use `run ! grep ...` for negative
Bats assertions: plain `! grep ...` can be ignored when another assertion follows.
Never execute real host updates, channel switches, package installs, or resets
in unit tests.

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

### Subagent factual claims need source verification

Architecture documents from subagents must be source-verified before committing.
Subagents have hallucinated file content and CI config state. Always `grep` the
actual file before accepting a claim about its contents or existence.
