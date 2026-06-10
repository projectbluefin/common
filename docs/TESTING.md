# Testing in `projectbluefin/common`

This document is the testing contract for the `common` repo. Read it before adding a new script to `system_files/`.

## Quick Start

```bash
just test          # run full test suite (pytest + bats)
just check         # lint Justfile
pre-commit run --all-files  # hygiene checks (shellcheck, yaml, sha-pinning)
```

## What Must Be Tested

### Rule: new script in `system_files/*/usr/bin/` → new test file in `tests/`

Every script added to `system_files/*/usr/bin/` must have either:
1. A `tests/test_<scriptname>.bats` file covering its branching logic, OR
2. A documented exemption in this file explaining why tests are not feasible.

Profile scripts (`etc/profile.d/*.sh`) are **shellcheck-only** — they run on login and have no testable logic beyond syntax.

## Test Frameworks

| Language | Framework | File pattern |
|----------|-----------|-------------|
| Shell scripts | [bats-core](https://bats-core.readthedocs.io/) | `tests/test_*.bats` |
| Python hooks | pytest | `tests/test_*.py` |

**Do not introduce additional frameworks.** `bats` for shell, `pytest` for Python. One convention, no exceptions.

## Hardware Gate Boundary

Some scripts interact with hardware that cannot be present in CI:

| Script | Hardware dependency | Test boundary |
|--------|--------------------|--------------------|
| `luks-tpm2-autounlock` | TPM2 chip | Test UUID parsing, device resolution, flag construction. Mock `gum` and `systemd-cryptenroll` via PATH. Full integration: `projectbluefin/testsuite`. |
| Any script using `gum` | Interactive TTY | Mock `gum` via PATH stub in `tests/` setup. |

**Never block CI on hardware.** Extract hardware-dependent calls behind mocked system boundaries.

## Bats Patterns

### Standard test file structure

```bash
#!/usr/bin/env bats
# Description of what's tested

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../path/to/script"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    # Mock any interactive commands via PATH
    mkdir -p "${WORKDIR}/bin"
    printf '#!/bin/bash\nexit 0\n' > "${WORKDIR}/bin/gum"
    chmod +x "${WORKDIR}/bin/gum"
    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "script: describes expected behavior precisely" {
    export SOME_CONFIG_FILE="${WORKDIR}/config.json"
    echo '{"key": "value"}' > "${SOME_CONFIG_FILE}"
    run bash "${SCRIPT_UNDER_TEST}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "expected output" ]
}
```

### Mocking system commands via PATH

The canonical pattern for mocking any command (`gum`, `systemd-cryptenroll`, `bootc`, `rpm-ostree`):

```bash
setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"

    # Mock that always succeeds
    printf '#!/bin/bash\nexit 0\n' > "${WORKDIR}/bin/gum"
    chmod +x "${WORKDIR}/bin/gum"

    # Mock that records its arguments for assertions
    printf '#!/bin/bash\necho "$*" >> %s/calls.log\nexit 0\n' "${WORKDIR}" \
        > "${WORKDIR}/bin/systemd-cryptenroll"
    chmod +x "${WORKDIR}/bin/systemd-cryptenroll"

    export PATH="${WORKDIR}/bin:${PATH}"
}
```

Then in tests: `grep -q "expected-flag" "${WORKDIR}/calls.log"`

### Making scripts testable via BASH_SOURCE guard

For scripts with top-level interactive code, wrap the main flow:

```bash
# Functions defined here are always loaded
get_foo() { ... }
check_bar() { ... }

# Main flow only runs when executed directly (not sourced for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gum confirm ...
    # rest of main flow
fi
```

Then in bats: `source "${SCRIPT}"` loads functions only. The interactive main flow does not run.

### Testability overrides via environment variables

For scripts that access system paths, use env-var overrides following the `:-` idiom:

```bash
CMDLINE_FILE="${CMDLINE_FILE:-/proc/cmdline}"
CONFIG_FILE="${CONFIG_FILE:-/etc/config.json}"
```

In tests: `export CMDLINE_FILE="${WORKDIR}/cmdline"` before running or sourcing.

This pattern is used in:
- `ublue-privileged-setup` → `SETUP_CONFIG_FILE`, `HOOKS_VERBOSE`
- `ublue-system-setup`, `ublue-user-setup` → same
- `luks-tpm2-autounlock` → `CMDLINE_FILE`, `DISK_BY_UUID_DIR`, `DEV_DIR`
- `ublue-bling` → `BLING_CLI_DIRECTORY`, `BLING_ENV_SCRIPT`
- `rechunker-group-fix` → `GSHADOW_FILE`, `GROUP_FILE` (**workaround**: script is itself a workaround for systemd/systemd#30852; remove overrides when script is deleted)

### Testing just recipes

Just recipes embed bash after a shebang line. Extract the body with `awk` for bats testing:

```bash
_extract_script() {
    local out_file="$1"
    awk '
        /^    #!\/usr\/bin\/bash/ { found=1; next }
        found { sub(/^    /, ""); print }
    ' "${JUSTFILE}" > "${out_file}"
}
```

Then run: `bash "${extracted_script}"` with mocked PATH binaries.

### Pitfall: literal `*` in bats grep assertions

`grep -q "^name:!*::"` treats `*` as a regex quantifier (zero-or-more `!`) — it will **not** match the literal string `name:!*::`. Always escape:

```bash
# WRONG — * is a quantifier, matches name::: or name:!:: etc.
grep -q "^name:!*::" file

# CORRECT — \* matches a literal asterisk
grep -q "^name:!\*::" file

# ALSO CORRECT — -F disables regex entirely
grep -qF "name:!*::" file
```

## Exemptions

Scripts exempt from behavioral testing (shellcheck-only):

| Script | Reason |
|--------|--------|
| `etc/profile.d/caffeinate.sh` | Profile.d sourced script — sets aliases only, no branching logic |
| `etc/profile.d/uutils.sh` | Profile.d sourced script — PATH manipulation only |
| `etc/profile.d/ublue-fastfetch.sh` | Profile.d sourced script — display only |
| `etc/profile.d/ublue-motd.sh` | Profile.d sourced script — display only |
| `etc/profile.d/umotd.sh` | Profile.d sourced script — display only |
| `usr/share/ublue-os/bling/bling.sh` | Sourced helper — sets aliases/functions, no side effects |
| `usr/share/ublue-os/bling/env.sh` | Sourced helper — sets env vars only |
| `usr/share/ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh` | One-shot hook — logic tested indirectly via setup integration tests |
| `usr/bin/ublue-motd` | Display-only wrapper — cosmetic tput/glow call, no decision logic |
| `usr/bin/ublue-image-info.sh` | Read-only reporting wrapper — jq + rpm-ostree status, no branching that affects system state |

**Adding an exemption:** add a row to this table with a one-sentence justification. Do not add exemptions for scripts with branching logic.

## Coverage Targets

| Layer | Tool | Current target |
|-------|------|---------------|
| Python hooks | pytest-cov | 80% via `--cov-fail-under=80` gate in CI |
| Shell scripts | shellcheck | 100% of all `.sh` + `usr/bin` scripts |
| Shell behavior | bats | All `usr/bin` scripts with branching logic |

## Test Files Reference

| File | What it covers |
|------|---------------|
| `tests/test_hooks.py` | `system_files/bluefin/etc/bazaar/hooks.py` — Bazaar transaction hooks |
| `tests/test_libsetup.bats` | `libsetup.sh` — `version-script()` function |
| `tests/test_setup_scripts.bats` | `ublue-system-setup`, `ublue-user-setup` — hook runner logic |
| `tests/test_privileged_setup.bats` | `ublue-privileged-setup` — privileged hook runner logic |
| `tests/test_bling.bats` | `ublue-bling` — shell config injection install/uninstall |
| `tests/test_luks_tpm2.bats` | `luks-tpm2-autounlock` — UUID parsing, device resolution, cryptenroll flag construction |
| `tests/test_rechunker_group_fix.bats` | `rechunker-group-fix` — group/gshadow append, duplicate detection, format |
| `tests/test_bling_fastfetch.bats` | `ublue-bling-fastfetch` — all 9 accent colors, dconf/gsettings fallback chain, FASTFETCH_FORCE_THEME override |
| `tests/test_changelog.bats` | `changelog.just` — LTS/non-LTS repo selection, URL construction, exit behaviour |
| `tests/test_ublue_fastfetch.bats` | `ublue-fastfetch` — config reads, shuffle branch, DEFAULT_THEME export to ublue-bling-fastfetch |

## Quality Epic

Ongoing test coverage improvement is tracked in [#553](https://github.com/projectbluefin/common/issues/553).
