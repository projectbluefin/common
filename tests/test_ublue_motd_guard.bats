#!/usr/bin/env bats
# Tests for the double-execution guard in system_files/shared/etc/profile.d/ublue-motd.sh
# and the env.sh existence guard in system_files/shared/usr/bin/ublue-motd.
#
# These tests validate the changes introduced by PR #795 (fix(motd): prevent
# double-execution and missing env.sh errors).
#
# Run: bats tests/test_ublue_motd_guard.bats

bats_require_minimum_version 1.5.0

MOTD_PROFILE="${BATS_TEST_DIRNAME}/../system_files/shared/etc/profile.d/ublue-motd.sh"
UBLUE_MOTD_BIN="${BATS_TEST_DIRNAME}/../system_files/shared/usr/bin/ublue-motd"
FISH_GREETING="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/fish/vendor_conf.d/fish_greeting.fish"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/home/.config" "${WORKDIR}/motd"

    # Mock ublue-motd — records invocations
    printf '#!/usr/bin/env bash\necho "ublue-motd" >> "%s/motd.log"\n' \
        "${WORKDIR}" > "${WORKDIR}/bin/ublue-motd"
    chmod +x "${WORKDIR}/bin/ublue-motd"

    export HOME="${WORKDIR}/home"
    export PATH="${WORKDIR}/bin:${PATH}"
    unset UBLUE_MOTD_SHOWN
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# ublue-motd.sh — double-execution guard
# ---------------------------------------------------------------------------

@test "ublue-motd.sh: first invocation runs ublue-motd" {
    run bash "${MOTD_PROFILE}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/motd.log" ]
    grep -q "ublue-motd" "${WORKDIR}/motd.log"
}

@test "ublue-motd.sh: first invocation exports UBLUE_MOTD_SHOWN=1" {
    run bash -c "source '${MOTD_PROFILE}'; echo \${UBLUE_MOTD_SHOWN:-unset}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"1"* ]]
}

@test "ublue-motd.sh: second invocation with UBLUE_MOTD_SHOWN=1 skips ublue-motd" {
    # Simulate what happens when profile.d is sourced twice in the same shell session
    run bash -c "
        export UBLUE_MOTD_SHOWN=1
        source '${MOTD_PROFILE}'
    "
    [ "${status}" -eq 0 ]
    [ ! -f "${WORKDIR}/motd.log" ]
}

@test "ublue-motd.sh: invocation skipped when no-show-user-motd exists" {
    touch "${HOME}/.config/no-show-user-motd"
    run bash "${MOTD_PROFILE}"
    [ "${status}" -eq 0 ]
    [ ! -f "${WORKDIR}/motd.log" ]
}

@test "ublue-motd.sh: contains UBLUE_MOTD_SHOWN guard" {
    grep -q 'UBLUE_MOTD_SHOWN' "${MOTD_PROFILE}"
}

@test "ublue-motd.sh: contains no-show-user-motd opt-out check" {
    grep -q 'no-show-user-motd' "${MOTD_PROFILE}"
}

# ---------------------------------------------------------------------------
# usr/bin/ublue-motd — env.sh existence guard
# ---------------------------------------------------------------------------

@test "ublue-motd bin: exits 0 when env.sh is missing" {
    # Without the guard (old code), sourcing a missing file would abort with exit 1
    run env \
        MOTD_ENV_SCRIPT="${WORKDIR}/nonexistent-env.sh" \
        MOTD_TEMPLATE_FILE="${WORKDIR}/motd/template.md" \
        sh "${UBLUE_MOTD_BIN}"
    [ "${status}" -eq 0 ]
}

@test "ublue-motd bin: sources env.sh when it exists" {
    printf '#!/usr/bin/env sh\nTEST_ENV_LOADED=1\n' > "${WORKDIR}/env.sh"
    run env \
        MOTD_ENV_SCRIPT="${WORKDIR}/env.sh" \
        MOTD_TEMPLATE_FILE="${WORKDIR}/motd/template.md" \
        sh "${UBLUE_MOTD_BIN}"
    [ "${status}" -eq 0 ]
}

@test "ublue-motd bin: contains [ -f ...] guard for env.sh" {
    grep -q '\[ -f' "${UBLUE_MOTD_BIN}"
}

# ---------------------------------------------------------------------------
# fish_greeting.fish — UBLUE_MOTD_SHOWN guard (static assertions)
# Fish is not required in CI; these are grep-based structural checks.
# ---------------------------------------------------------------------------

@test "fish_greeting: contains UBLUE_MOTD_SHOWN guard" {
    grep -q 'UBLUE_MOTD_SHOWN' "${FISH_GREETING}"
}

@test "fish_greeting: sets UBLUE_MOTD_SHOWN after invoking ublue-motd" {
    grep -q 'set -gx UBLUE_MOTD_SHOWN 1' "${FISH_GREETING}"
}

@test "fish_greeting: still checks no-show-user-motd opt-out" {
    grep -q 'no-show-user-motd' "${FISH_GREETING}"
}
