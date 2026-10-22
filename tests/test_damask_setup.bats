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

    mkdir -p "${WORKDIR}/caskroom/bluefin-wallpapers-extra/v1/images"
    printf '<svg/>\n' > "${WORKDIR}/caskroom/bluefin-wallpapers-extra/v1/images/example.svg"
    printf 'v1\n' > "${WORKDIR}/artwork-version"
    cat > "${WORKDIR}/bin/brew" << MOCK
#!/bin/bash
case "\$1" in
    --caskroom) printf '%s\\n' '${WORKDIR}/caskroom/bluefin-wallpapers-extra' ;;
    info) jq -n --arg installed "\$(cat '${WORKDIR}/artwork-version')" '{casks: [{installed: \$installed}]}' ;;
esac
MOCK
    chmod +x "${WORKDIR}/bin/brew"
    export BREW_BIN="${WORKDIR}/bin/brew"

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

@test "25-damask-setup: seeds a user folder pointing to installed artwork without activating Slideshow" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    python3 - "${HOME}" "${WORKDIR}/caskroom/bluefin-wallpapers-extra/v1/images" << 'PY'
import configparser
import pathlib
import sys

home = pathlib.Path(sys.argv[1])
folder = home / ".local/share/backgrounds/bluefin-extra"
settings = configparser.ConfigParser(interpolation=None)
settings.read(home / ".var/app/app.drey.Damask/config/glib-2.0/settings/keyfile")
assert settings["app/drey/Damask"]["active-source"] == "'none'"
assert settings["app/drey/Damask/sources/slideshow"]["folder-uri"] == repr(folder.as_uri())
assert folder.is_symlink()
assert folder.resolve() == pathlib.Path(sys.argv[2])
assert (folder / "example.svg").read_text() == "<svg/>\n"
PY
}

@test "25-damask-setup: first run enables damask.service for current user" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    grep -qx -- "--user enable damask.service" "${WORKDIR}/systemctl.log"
    ! grep -q -- "--system" "${WORKDIR}/systemctl.log"
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

@test "25-damask-setup: a failing systemctl leaves no version stamp so the hook retries" {
    echo 1 > "${WORKDIR}/systemctl.rc"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -ne 0 ]
    [ "$(jq -r '.version.user."damask-setup"' "${SETUP_CHECKER_FILE}")" = "null" ]

    # Next boot: systemctl works again and the hook runs its body and stamps.
    echo 0 > "${WORKDIR}/systemctl.rc"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    grep -qx -- "--user enable damask.service" "${WORKDIR}/systemctl.log"
    [ "$(jq -r '.version.user."damask-setup"' "${SETUP_CHECKER_FILE}")" = "1" ]
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

@test "25-damask-setup: keeps the folder pointer current after a Homebrew upgrade without rewriting settings" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    local keyfile="${HOME}/.var/app/app.drey.Damask/config/glib-2.0/settings/keyfile"
    printf '\n# user preferences\n' >> "${keyfile}"
    cp "${keyfile}" "${WORKDIR}/expected-keyfile"

    mkdir -p "${WORKDIR}/caskroom/bluefin-wallpapers-extra/v2/images"
    printf '<svg>updated</svg>\n' > "${WORKDIR}/caskroom/bluefin-wallpapers-extra/v2/images/example.svg"
    printf 'v2\n' > "${WORKDIR}/artwork-version"
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    [ "$(cat "${HOME}/.local/share/backgrounds/bluefin-extra/example.svg")" = '<svg>updated</svg>' ]
    cmp "${WORKDIR}/expected-keyfile" "${keyfile}"
}

@test "25-damask-setup: does not seed or stamp before the artwork is installed" {
    printf '\n' > "${WORKDIR}/artwork-version"
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.var/app/app.drey.Damask/config/glib-2.0/settings/keyfile" ]
    [ ! -e "${SETUP_CHECKER_FILE}" ]

    printf 'v1\n' > "${WORKDIR}/artwork-version"
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    [ -L "${HOME}/.local/share/backgrounds/bluefin-extra" ]
}
