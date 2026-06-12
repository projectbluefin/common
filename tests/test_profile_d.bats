#!/usr/bin/env bats
# Tests for system_files/bluefin/etc/profile.d/caffeinate.sh
#          system_files/bluefin/etc/profile.d/uutils.sh
#
# Run: bats tests/test_profile_d.bats

CAFFEINATE_SCRIPT="$BATS_TEST_DIRNAME/../system_files/bluefin/etc/profile.d/caffeinate.sh"
UUTILS_SCRIPT="$BATS_TEST_DIRNAME/../system_files/bluefin/etc/profile.d/uutils.sh"
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
    [[ "${output}" == *"--what=idle"* ]]
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
    [[ "${output}" == *"--what=idle"* ]]
    [[ "${output}" == *"--who=caffeinate"* ]]
    [[ "${output}" == *"make test"* ]]
}

# ---------------------------------------------------------------------------
# uutils.sh — non-interactive shell (PATH must not be modified)
#
# Use a sanitised PATH (no pre-existing uubin from the host) so tests are
# reproducible even on machines where linuxbrew is installed.
# ---------------------------------------------------------------------------

@test "uutils: PATH is unchanged when sourced in a non-interactive shell" {
    run bash -c "PATH='/usr/bin:/bin'; source '${UUTILS_SCRIPT}'; printf '%s\n' \"\${PATH}\""
    [ "${status}" -eq 0 ]
    [ "${output}" = "/usr/bin:/bin" ]
}

@test "uutils: uubin prefix is absent from PATH in non-interactive shell" {
    run bash -c "PATH='/usr/bin:/bin'; source '${UUTILS_SCRIPT}'; printf '%s\n' \"\${PATH}\""
    [ "${status}" -eq 0 ]
    [[ "${output}" != */uubin* ]]
}

# ---------------------------------------------------------------------------
# uutils.sh — dirs absent (PATH must not be modified)
# ---------------------------------------------------------------------------

@test "uutils: PATH is unchanged when uubin dirs are absent" {
    # Patch directory path to a temp location where the dirs do NOT exist,
    # and bypass the interactive-shell check so the only guard is the -d test.
    PATCHED="${WORKDIR}/uutils_nodirs.sh"
    sed -e "s|/home/linuxbrew|${WORKDIR}/linuxbrew|g" \
        -e 's/\$- == \*i\*/true/' \
        "${UUTILS_SCRIPT}" > "${PATCHED}"

    run bash -c "PATH='/usr/bin:/bin'; source '${PATCHED}'; printf '%s\n' \"\${PATH}\""
    [ "${status}" -eq 0 ]
    [ "${output}" = "/usr/bin:/bin" ]
}

# ---------------------------------------------------------------------------
# uutils.sh — dirs present (PATH must be prepended)
#
# We test the PATH-modification logic without relying on bash -i (which
# triggers .bashrc / MOTD noise).  Instead we patch both the hard-coded
# linuxbrew path AND the \$- interactive check so the block always runs.
# ---------------------------------------------------------------------------

_patch_uutils_active() {
    # Produce a patched copy where:
    #   /home/linuxbrew  →  ${WORKDIR}/linuxbrew  (controllable dirs)
    #   $- == *i*        →  true                  (always enter the block)
    local patched="${WORKDIR}/uutils_active.sh"
    sed -e "s|/home/linuxbrew|${WORKDIR}/linuxbrew|g" \
        -e 's/\$- == \*i\*/true/' \
        "${UUTILS_SCRIPT}" > "${patched}"
    echo "${patched}"
}

_create_uubin_dirs() {
    mkdir -p "${WORKDIR}/linuxbrew/.linuxbrew/opt/uutils-coreutils/libexec/uubin"
    mkdir -p "${WORKDIR}/linuxbrew/.linuxbrew/opt/uutils-diffutils/libexec/uubin"
    mkdir -p "${WORKDIR}/linuxbrew/.linuxbrew/opt/uutils-findutils/libexec/uubin"
}

@test "uutils: PATH is prepended with all three uubin dirs when dirs exist" {
    _create_uubin_dirs
    PATCHED="$(_patch_uutils_active)"

    run bash -c "PATH='/usr/bin:/bin'; source '${PATCHED}'; printf '%s\n' \"\${PATH}\""
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"uutils-coreutils/libexec/uubin"* ]]
    [[ "${output}" == *"uutils-diffutils/libexec/uubin"* ]]
    [[ "${output}" == *"uutils-findutils/libexec/uubin"* ]]
}

@test "uutils: uubin dirs appear before original PATH entries" {
    _create_uubin_dirs
    PATCHED="$(_patch_uutils_active)"

    run bash -c "PATH='/usr/bin:/bin'; source '${PATCHED}'; printf '%s\n' \"\${PATH}\""
    [ "${status}" -eq 0 ]
    # uubin must appear before /usr/bin in the colon-separated PATH
    [[ "${output}" =~ uubin.*:/usr/bin ]]
}

@test "uutils: stty alias is set to /usr/bin/stty when dirs exist" {
    _create_uubin_dirs
    PATCHED="$(_patch_uutils_active)"

    run bash -c "source '${PATCHED}'; alias stty 2>/dev/null"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"/usr/bin/stty"* ]]
}

@test "uutils: only coreutils dir existence gates the block" {
    # Only create the coreutils dir — the script checks only this path
    mkdir -p "${WORKDIR}/linuxbrew/.linuxbrew/opt/uutils-coreutils/libexec/uubin"
    PATCHED="$(_patch_uutils_active)"

    run bash -c "PATH='/usr/bin:/bin'; source '${PATCHED}'; printf '%s\n' \"\${PATH}\""
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"uutils-coreutils/libexec/uubin"* ]]
}
