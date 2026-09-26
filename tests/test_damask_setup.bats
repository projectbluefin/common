#!/usr/bin/env bats
# Tests for system_files/bluefin/usr/share/ublue-os/user-setup.hooks.d/25-damask-setup.sh
#
# Run: bats tests/test_damask_setup.bats

REPO_ROOT="$BATS_TEST_DIRNAME/.."
DAMASK_HOOK="${REPO_ROOT}/system_files/bluefin/usr/share/ublue-os/user-setup.hooks.d/25-damask-setup.sh"
LIBSETUP_REAL="${REPO_ROOT}/system_files/shared/usr/lib/ublue/setup-services/libsetup.sh"

WORKDIR=""
PATCHED_HOOK=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/home"

    echo 0 > "${WORKDIR}/systemctl.rc"
    echo 0 > "${WORKDIR}/systemctl-list.rc"

    cat > "${WORKDIR}/bin/systemctl" << MOCK
#!/bin/bash
echo "\$*" >> "${WORKDIR}/systemctl.log"
if [[ "\$*" == *"list-unit-files damask.service"* ]]; then
    exit "\$(cat "${WORKDIR}/systemctl-list.rc" 2>/dev/null || echo 0)"
fi
exit "\$(cat "${WORKDIR}/systemctl.rc")"
MOCK
    chmod +x "${WORKDIR}/bin/systemctl"
    echo 0 > "${WORKDIR}/flatpak.rc"
    cat > "${WORKDIR}/bin/flatpak" << MOCK
#!/bin/bash
echo "\$*" >> "${WORKDIR}/flatpak.log"
exit "\$(cat "${WORKDIR}/flatpak.rc")"
MOCK
    chmod +x "${WORKDIR}/bin/flatpak"

    # Patch the absolute source path so hook runs against the real libsetup.sh in the repo.
    PATCHED_HOOK="${WORKDIR}/25-damask-setup.sh"
    sed \
        -e "s|source /usr/lib/ublue/setup-services/libsetup.sh|source ${LIBSETUP_REAL}|g" \
        "${DAMASK_HOOK}" > "${PATCHED_HOOK}"
    chmod +x "${PATCHED_HOOK}"

    export PATH="${WORKDIR}/bin:${PATH}"
    export HOME="${WORKDIR}/home"
    unset XDG_CONFIG_HOME
    export SETUP_CHECKER_FILE="${WORKDIR}/setup_versioning.json"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "25-damask-setup: first run creates keyfile with expected content and permissions" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    local keyfile="${HOME}/.var/app/app.drey.Damask/config/glib-2.0/settings/keyfile"
    [ -f "${keyfile}" ]

    # Verify file permissions are 0644
    local perms
    perms="$(stat -c "%a" "${keyfile}")"
    [ "${perms}" = "644" ]

    # Verify root preferences section
    grep -qx "\[app/drey/Damask\]" "${keyfile}"
    grep -qx "refresh-interval='86400'" "${keyfile}"
    grep -qx "enable-automatic-refresh=true" "${keyfile}"
    grep -qx "run-in-background=true" "${keyfile}"
    grep -qx "active-source='none'" "${keyfile}"

    # Verify slideshow plugin source section
    grep -qx "\[app/drey/Damask/sources/slideshow\]" "${keyfile}"
    grep -qx "folder-uri='file:///run/host/usr/share/backgrounds/bluefin'" "${keyfile}"
    grep -qx "sort-by='random'" "${keyfile}"
}

@test "25-damask-setup: first run enables damask.service for current user" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    grep -qx -- "--user enable damask.service" "${WORKDIR}/systemctl.log"
    ! grep -q -- "--system" "${WORKDIR}/systemctl.log"
}

@test "25-damask-setup: records version 1 under user service namespace" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    [ "$(jq -r '.version.user."damask-setup"' "${SETUP_CHECKER_FILE}")" = "1" ]
}

@test "25-damask-setup: version-script gate makes a second run a no-op" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    # Modify the keyfile to verify second run doesn't overwrite it
    local keyfile="${HOME}/.var/app/app.drey.Damask/config/glib-2.0/settings/keyfile"
    echo "# user modified" >> "${keyfile}"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    # The hook body must not run again: exactly one enable, and no second
    # unit-file probe. Counting every logged call would also count the
    # list-unit-files probe the first run makes.
    [ "$(grep -c -x -- "--user enable damask.service" "${WORKDIR}/systemctl.log")" -eq 1 ]
    [ "$(grep -c -x -- "--user list-unit-files damask.service" "${WORKDIR}/systemctl.log")" -eq 1 ]

    # user modification should still be present
    grep -qx "# user modified" "${keyfile}"
}

@test "25-damask-setup: non-destructive when keyfile already exists before first run" {
    local keyfile_dir="${HOME}/.var/app/app.drey.Damask/config/glib-2.0/settings"
    mkdir -p "${keyfile_dir}"
    cat > "${keyfile_dir}/keyfile" << 'EXISTING'
[app/drey/Damask]
active-source='wallhaven'
EXISTING

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    # Existing content preserved
    grep -qx "active-source='wallhaven'" "${keyfile_dir}/keyfile"
    run grep -qx "active-source='none'" "${keyfile_dir}/keyfile"
    [ "${status}" -ne 0 ]

    # systemctl was still called
    grep -qx -- "--user enable damask.service" "${WORKDIR}/systemctl.log"
}

@test "25-damask-setup: a failing systemctl causes the hook to exit with failure" {
    echo 1 > "${WORKDIR}/systemctl.rc"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -ne 0 ]
}

@test "25-damask-setup: gracefully skips enable if damask.service does not exist" {
    echo 1 > "${WORKDIR}/systemctl-list.rc"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    grep -q -- "list-unit-files damask.service" "${WORKDIR}/systemctl.log"
    ! grep -q -- "--user enable damask.service" "${WORKDIR}/systemctl.log"
}

@test "25-damask-setup: exits cleanly without creating keyfile or stamping when Damask is not installed" {
    echo 1 > "${WORKDIR}/flatpak.rc"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    local keyfile="${HOME}/.var/app/app.drey.Damask/config/glib-2.0/settings/keyfile"
    [ ! -f "${keyfile}" ]
    [ ! -f "${SETUP_CHECKER_FILE}" ]
}
