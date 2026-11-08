# Bats Patterns

Part of [shell-scripts](../SKILL.md) — compact reference for bats test file structure, mocking, and assertion pitfalls.

## Standard test file structure

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

## Mocking system commands via PATH

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

## Testing just recipes

Just recipes embed bash after a shebang line. Extract the body with `awk` for
bats testing:

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

## Pitfall: literal `*` in bats grep assertions

`grep -q "^name:!*::"` treats `*` as a regex quantifier (zero-or-more `!`) —
it will **not** match the literal string `name:!*::`. Always escape:

```bash
# WRONG — * is a quantifier
grep -q "^name:!*::" file

# CORRECT — \* matches a literal asterisk
grep -q "^name:!\*::" file

# ALSO CORRECT — -F disables regex entirely
grep -qF "name:!*::" file
```

## Isolating environment in profile/login scripts

Scripts under `etc/profile.d/` often check guard variables (e.g. `UWELCOME_SHOWN`)
to prevent duplicate execution across chained shells. When bats runs in an
interactive login session, those guard variables are already set in the caller's
environment, causing tests to fail silently or unexpectedly skip script bodies.
Always unset or isolate session guard variables in `setup()`:

```bash
setup() {
    WORKDIR="$(mktemp -d)"
    ...
    unset UWELCOME_SHOWN
}
```

## Bash DEBUG traps are invisible inside functions

Without `set -o functrace`, bash does **not** inherit the `DEBUG` trap into
shell functions. Two consequences bite when testing or writing prompt hooks:

```bash
f() { echo "[$(trap -p DEBUG)]"; }   # always prints [] — even when a trap is set
g() { trap - DEBUG; }                # does NOT clear the caller's DEBUG trap
h() { trap 'cmd' DEBUG; }            # DOES set the caller's DEBUG trap
```

So `trap -p DEBUG` is useless as a detector from inside a function, while
`trap ... DEBUG` from inside a function is a reliable way to (re-)install one.

For bats: `PROMPT_COMMAND` entries execute at **top level** in a real shell.
Simulate a prompt cycle with a top-level loop, never a helper function —
wrapping the cycle in a function hides `trap - DEBUG` clobbers entirely and
makes the test pass vacuously.

```bash
CYCLE='for __e in "${PROMPT_COMMAND[@]}"; do eval "$__e"; done'
```

See `tests/test_bling_preexec_rearm.bats` and
[#869](https://github.com/projectbluefin/common/issues/869).
