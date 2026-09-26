#!/usr/bin/env bats
# Tests for system_files/bluefin/usr/share/ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh
#
# Run: bats tests/test_dynamic_wallpaper_hook.bats

REPO_ROOT="$BATS_TEST_DIRNAME/.."
WALLPAPER_HOOK="${REPO_ROOT}/system_files/bluefin/usr/share/ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh"
LIBSETUP_REAL="${REPO_ROOT}/system_files/shared/usr/lib/ublue/setup-services/libsetup.sh"
TIMER_UNIT="${REPO_ROOT}/system_files/bluefin/usr/lib/systemd/user/bluefin-dynamic-wallpaper.timer"

WORKDIR=""
PATCHED_HOOK=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"

    # Exit codes the mocks below read, so a test can make either dependency fail.
    echo 0 > "${WORKDIR}/systemctl.rc"
    echo 0 > "${WORKDIR}/wallpaper.rc"

    cat > "${WORKDIR}/bin/systemctl" << MOCK
#!/bin/bash
echo "\$*" >> "${WORKDIR}/systemctl.log"
exit "\$(cat "${WORKDIR}/systemctl.rc")"
MOCK
    chmod +x "${WORKDIR}/bin/systemctl"

    cat > "${WORKDIR}/bin/bluefin-dynamic-wallpaper" << MOCK
#!/bin/bash
echo "invoked" >> "${WORKDIR}/wallpaper.log"
exit "\$(cat "${WORKDIR}/wallpaper.rc")"
MOCK
    chmod +x "${WORKDIR}/bin/bluefin-dynamic-wallpaper"

    # Patch the absolute paths the hook uses so it runs against the real
    # libsetup.sh and the mock helper instead of an installed image.
    PATCHED_HOOK="${WORKDIR}/20-dynamic-wallpaper.sh"
    sed \
        -e "s|source /usr/lib/ublue/setup-services/libsetup.sh|source ${LIBSETUP_REAL}|g" \
        -e "s|/usr/libexec/bluefin-dynamic-wallpaper|${WORKDIR}/bin/bluefin-dynamic-wallpaper|g" \
        "${WALLPAPER_HOOK}" > "${PATCHED_HOOK}"
    chmod +x "${PATCHED_HOOK}"

    export PATH="${WORKDIR}/bin:${PATH}"
    export SETUP_CHECKER_FILE="${WORKDIR}/setup_versioning.json"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "20-dynamic-wallpaper: first run enables the timer and sets the initial wallpaper" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    grep -qx -- "--user enable --now bluefin-dynamic-wallpaper.timer" "${WORKDIR}/systemctl.log"
    [ "$(wc -l < "${WORKDIR}/wallpaper.log")" -eq 1 ]
}

@test "20-dynamic-wallpaper: the timer it enables is the unit shipped by this repo" {
    [ -f "${TIMER_UNIT}" ]
}

@test "20-dynamic-wallpaper: enabling the timer is a --user (not system) operation" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    ! grep -q -- "--system" "${WORKDIR}/systemctl.log"
}

@test "20-dynamic-wallpaper: records version 1 under the user service namespace" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    [ "$(jq -r '.version.user."dynamic-wallpaper"' "${SETUP_CHECKER_FILE}")" = "1" ]
}

@test "20-dynamic-wallpaper: version-script gate makes a second run a no-op" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    [ "$(wc -l < "${WORKDIR}/systemctl.log")" -eq 1 ]
    [ "$(wc -l < "${WORKDIR}/wallpaper.log")" -eq 1 ]
}

@test "20-dynamic-wallpaper: a failing wallpaper helper does not fail the hook" {
    echo 1 > "${WORKDIR}/wallpaper.rc"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    grep -qx -- "--user enable --now bluefin-dynamic-wallpaper.timer" "${WORKDIR}/systemctl.log"
    [ "$(wc -l < "${WORKDIR}/wallpaper.log")" -eq 1 ]
}

@test "20-dynamic-wallpaper: a failing systemctl aborts before the wallpaper is set" {
    echo 1 > "${WORKDIR}/systemctl.rc"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -ne 0 ]
    [ ! -e "${WORKDIR}/wallpaper.log" ]
}

# Regression guard for projectbluefin/common#1137: version-script is now a pure
# read gate and the version is only committed by version-script-commit at the
# end of the body. A run that dies at `systemctl enable` must NOT burn the
# version, so a later healthy run retries instead of being permanently skipped.
@test "20-dynamic-wallpaper: a failed run retries instead of burning the version" {
    echo 1 > "${WORKDIR}/systemctl.rc"
    run bash "${PATCHED_HOOK}"
    [ "${status}" -ne 0 ]
    # the body failed before version-script-commit, so nothing is recorded
    [ "$(jq -r '.version.user."dynamic-wallpaper"' "${SETUP_CHECKER_FILE}" 2>/dev/null)" = "null" ]

    echo 0 > "${WORKDIR}/systemctl.rc"
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    # it retried: the wallpaper runs again and the version is now recorded
    [ "$(wc -l < "${WORKDIR}/wallpaper.log")" -eq 1 ]
    [ "$(jq -r '.version.user."dynamic-wallpaper"' "${SETUP_CHECKER_FILE}")" = "1" ]
}
