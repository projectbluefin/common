#!/usr/bin/env bats
# Tests for system_files/shared/etc/profile.d/uwelcome.sh
#
# Run: bats tests/test_uwelcome_profile.bats

UWELCOME_PROFILE="$BATS_TEST_DIRNAME/../system_files/shared/etc/profile.d/uwelcome.sh"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/home/.config"

    # Mock uwelcome — records every invocation so tests can assert it ran
    cat > "${WORKDIR}/bin/uwelcome" << MOCK
#!/bin/bash
echo "uwelcome-called" >> "${WORKDIR}/calls"
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/uwelcome"

    export HOME="${WORKDIR}/home"
    export PATH="${WORKDIR}/bin:${PATH}"

    # Inherited from the host login shell on Bluefin; would make the root-guard
    # tests pass vacuously via the UWELCOME_SHOWN guard.
    unset UWELCOME_SHOWN
}

teardown() {
    [ -n "${WORKDIR}" ] && rm -rf "${WORKDIR}"
}

# Mock `id` so the root branch can be exercised without being root.
stub_id() {
    cat > "${WORKDIR}/bin/id" << MOCK
#!/bin/bash
echo "$1"
MOCK
    chmod +x "${WORKDIR}/bin/id"
}

called() {
    [ -f "${WORKDIR}/calls" ]
}

# Use instead of `! called`: errexit ignores failures of !-inverted commands, so
# `! called` only asserts while it is the final command of a test.
not_called() {
    [ ! -f "${WORKDIR}/calls" ]
}

# The greeting only runs on a terminal, so tests that exercise the greeting
# guards run the profile under script(1), which gives it a pty.
run_tty() {
    run script -qec "$1" /dev/null
}

@test "legacy no-show-user-motd marker migrates to uwelcome/disabled" {
    stub_id 1000
    touch "${HOME}/.config/no-show-user-motd"

    run bash --norc -ic '. "$1"' _ "$UWELCOME_PROFILE"

    [ "$status" -eq 0 ]
    [ -f "${HOME}/.config/uwelcome/disabled" ]
    [ ! -e "${HOME}/.config/no-show-user-motd" ]
}

@test "no uwelcome config directory is created when the legacy marker is absent" {
    stub_id 1000

    run bash --norc -ic '. "$1"' _ "$UWELCOME_PROFILE"

    [ "$status" -eq 0 ]
    [ ! -d "${HOME}/.config/uwelcome" ]
}

@test "migration preserves an existing uwelcome directory and its contents" {
    stub_id 1000
    mkdir -p "${HOME}/.config/uwelcome"
    echo "keep-me" > "${HOME}/.config/uwelcome/state"
    touch "${HOME}/.config/no-show-user-motd"

    run bash --norc -ic '. "$1"' _ "$UWELCOME_PROFILE"

    [ "$status" -eq 0 ]
    [ -f "${HOME}/.config/uwelcome/disabled" ]
    [ "$(cat "${HOME}/.config/uwelcome/state")" = "keep-me" ]
}

@test "uwelcome runs for a non-root user with UWELCOME_SHOWN unset" {
    stub_id 1000
    unset UWELCOME_SHOWN

    run_tty "bash --norc -ic '. \"$UWELCOME_PROFILE\"'"

    [ "$status" -eq 0 ]
    called
    [ "$(cat "${WORKDIR}/calls")" = "uwelcome-called" ]
}

@test "uwelcome is skipped for root" {
    stub_id 0

    run_tty "bash --norc -ic '. \"$UWELCOME_PROFILE\"'"

    [ "$status" -eq 0 ]
    not_called
}

@test "uwelcome is skipped when UWELCOME_SHOWN is already set (no double greeting)" {
    stub_id 1000
    export UWELCOME_SHOWN=1

    run_tty "bash --norc -ic '. \"$UWELCOME_PROFILE\"'"

    [ "$status" -eq 0 ]
    not_called
}

@test "UWELCOME_SHOWN is exported so a chained shell does not greet twice" {
    stub_id 1000
    unset UWELCOME_SHOWN

    # Source the profile in an interactive shell, then start a child
    # interactive shell that sources it again.
    run_tty "bash --norc -ic '. \"$UWELCOME_PROFILE\"; bash --norc -ic \". \\\"$UWELCOME_PROFILE\\\"\"'"

    [ "$status" -eq 0 ]
    [ "$(wc -l < "${WORKDIR}/calls")" -eq 1 ]
}

@test "root still gets the legacy marker migrated even though the greeting is skipped" {
    stub_id 0
    touch "${HOME}/.config/no-show-user-motd"

    run bash --norc -ic '. "$1"' _ "$UWELCOME_PROFILE"

    [ "$status" -eq 0 ]
    [ -f "${HOME}/.config/uwelcome/disabled" ]
    not_called
}

@test "an empty UWELCOME_SHOWN is treated as unset and the greeting runs" {
    stub_id 1000
    export UWELCOME_SHOWN=""

    run_tty "bash --norc -ic '. \"$UWELCOME_PROFILE\"'"

    [ "$status" -eq 0 ]
    called
}

@test "uwelcome is skipped without a terminal (GDM's login shell)" {
    stub_id 1000
    unset UWELCOME_SHOWN

    run bash --norc -ic '. "$1"' _ "$UWELCOME_PROFILE" < /dev/null > /dev/null

    [ "$status" -eq 0 ]
    not_called
}

@test "a non-interactive shell sourcing the profile neither greets nor exports UWELCOME_SHOWN" {
    stub_id 1000
    unset UWELCOME_SHOWN

    # A pty is present, as for GDM's session shell; only interactivity is missing.
    run_tty "bash --norc -c '. \"$UWELCOME_PROFILE\"; echo \"shown=\${UWELCOME_SHOWN-unset}\"'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"shown=unset"* ]]
    not_called
}
