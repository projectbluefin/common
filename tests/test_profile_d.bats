#!/usr/bin/env bats
# Tests for system_files/bluefin/etc/profile.d/caffeinate.sh
#
# Run: bats tests/test_profile_d.bats

CAFFEINATE_SCRIPT="$BATS_TEST_DIRNAME/../system_files/shared/etc/profile.d/caffeinate.sh"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"

    # Mock systemd-inhibit — records invocation args and exits 0
    cat > "${WORKDIR}/bin/systemd-inhibit" << 'MOCK'
#!/bin/bash
echo "systemd-inhibit: $*"
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/systemd-inhibit"

    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# caffeinate.sh — function definition
# ---------------------------------------------------------------------------

@test "caffeinate: function is defined after sourcing" {
    run bash -c "source '${CAFFEINATE_SCRIPT}'; type caffeinate"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"caffeinate is a function"* ]]
}

# ---------------------------------------------------------------------------
# caffeinate.sh — no-argument invocation
# ---------------------------------------------------------------------------

@test "caffeinate: no-arg invocation calls systemd-inhibit with sleep infinity" {
    run bash -c "
        export PATH='${WORKDIR}/bin:\${PATH}'
        source '${CAFFEINATE_SCRIPT}'
        caffeinate
    "
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"sleep infinity"* ]]
}

@test "caffeinate: no-arg invocation passes correct inhibit flags" {
    run bash -c "
        export PATH='${WORKDIR}/bin:\${PATH}'
        source '${CAFFEINATE_SCRIPT}'
        caffeinate
    "
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--what=idle:sleep:handle-lid-switch"* ]]
    [[ "${output}" == *"--who=caffeinate"* ]]
    [[ "${output}" == *"--mode=block"* ]]
}

# ---------------------------------------------------------------------------
# caffeinate.sh — with-argument invocation
# ---------------------------------------------------------------------------

@test "caffeinate: with-arg invocation passes args through to systemd-inhibit" {
    run bash -c "
        export PATH='${WORKDIR}/bin:\${PATH}'
        source '${CAFFEINATE_SCRIPT}'
        caffeinate sleep 30
    "
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"sleep 30"* ]]
}

@test "caffeinate: with-arg invocation still passes correct inhibit flags" {
    run bash -c "
        export PATH='${WORKDIR}/bin:\${PATH}'
        source '${CAFFEINATE_SCRIPT}'
        caffeinate make test
    "
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--what=idle:sleep:handle-lid-switch"* ]]
    [[ "${output}" == *"--who=caffeinate"* ]]
    [[ "${output}" == *"make test"* ]]
}
