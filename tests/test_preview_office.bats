#!/usr/bin/env bats
# Tests for 15-preview-office.sh and the host-Sushi previewer artifacts it
# depends on:
#   - system_files/shared/usr/local/share/dbus-1/services/org.gnome.NautilusPreviewer.service
#   - system_files/bluefin/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile
#
# The hook patches only its hardcoded system paths; production behavior is
# unchanged. Run: bats tests/test_preview_office.bats

PREVIEW_HOOK="$BATS_TEST_DIRNAME/../system_files/shared/usr/share/ublue-os/user-setup.hooks.d/15-preview-office.sh"
LIBSETUP_REAL="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/ublue/setup-services/libsetup.sh"

BREWFILE="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile"
SERVICE_FILE="$BATS_TEST_DIRNAME/../system_files/shared/usr/local/share/dbus-1/services/org.gnome.NautilusPreviewer.service"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    export WORKDIR
    export HOME="${WORKDIR}/home"
    mkdir -p "${HOME}/.local/share/ublue"

    mkdir -p "${WORKDIR}/bin"
    cat > "${WORKDIR}/bin/systemctl" << 'SYSTEMCTL_MOCK'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "${WORKDIR}/systemctl.log"
SYSTEMCTL_MOCK
    chmod +x "${WORKDIR}/bin/systemctl"
    export PATH="${WORKDIR}/bin:${PATH}"

    # Default: host sushi is installed. Ship the service + libexec binary.
    mkdir -p "${WORKDIR}/usr/local/share/dbus-1/services" "${WORKDIR}/usr/libexec"
    printf '[D-Bus Service]\nName=org.gnome.NautilusPreviewer\nExec=/usr/libexec/org.gnome.NautilusPreviewer\n' \
        > "${WORKDIR}/usr/local/share/dbus-1/services/org.gnome.NautilusPreviewer.service"
    : > "${WORKDIR}/usr/libexec/org.gnome.NautilusPreviewer"
    chmod +x "${WORKDIR}/usr/libexec/org.gnome.NautilusPreviewer"
}

teardown() {
    rm -rf "${WORKDIR}"
}

_patched_script() {
    local patched_script="${WORKDIR}/preview-patched.sh"
    sed \
        -e "s|source /usr/lib/ublue/setup-services/libsetup.sh|source ${LIBSETUP_REAL}|" \
        -e "s|/usr/local/share/dbus-1/services/org.gnome.NautilusPreviewer.service|${WORKDIR}/usr/local/share/dbus-1/services/org.gnome.NautilusPreviewer.service|g" \
        -e "s|/usr/libexec/org.gnome.NautilusPreviewer|${WORKDIR}/usr/libexec/org.gnome.NautilusPreviewer|g" \
        "${PREVIEW_HOOK}" > "${patched_script}"
    chmod +x "${patched_script}"
    printf '%s\n' "${patched_script}"
}

@test "preview-office: first run installs the service (active on next login)" {
    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    # No in-session reload: the active previewer takes effect on next login.
    [ ! -e "${WORKDIR}/systemctl.log" ]
    [[ "${output}" == *"host Sushi is the Nautilus floating previewer"* ]]
}

@test "preview-office: second run is a no-op because version-script recorded it" {
    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    rm -f "${WORKDIR}/systemctl.log"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [ ! -e "${WORKDIR}/systemctl.log" ]
}

@test "preview-office: exits and retries when host sushi is not installed yet" {
    rm -f "${WORKDIR}/usr/libexec/org.gnome.NautilusPreviewer"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"host sushi not installed, will retry on next login"* ]]
    [ ! -e "${WORKDIR}/systemctl.log" ]
    # version-script must NOT record completion, so it retries next login.
    [ ! -e "${HOME}/.local/share/ublue/setup_versioning.json" ]
}

@test "preview-office: exits and retries when the shipped service file is missing" {
    rm -f "${WORKDIR}/usr/local/share/dbus-1/services/org.gnome.NautilusPreviewer.service"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"host sushi not installed, will retry on next login"* ]]
}

@test "preview-office: preserves an existing user-local previewer override" {
    mkdir -p "${HOME}/.local/share/dbus-1/services"
    printf '[D-Bus Service]\nName=org.gnome.NautilusPreviewer\nExec=/usr/bin/custom-previewer\n' \
        > "${HOME}/.local/share/dbus-1/services/org.gnome.NautilusPreviewer.service"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"preserving existing user-local previewer override"* ]]
    # The user override is untouched — the hook never writes it.
    grep -Fx -- 'Exec=/usr/bin/custom-previewer' \
        "${HOME}/.local/share/dbus-1/services/org.gnome.NautilusPreviewer.service"
}

@test "preview-office: shipped D-Bus service declares the host sushi Exec" {
    grep -Fx -- 'Name=org.gnome.NautilusPreviewer' "${SERVICE_FILE}"
    grep -Fx -- 'Exec=/usr/libexec/org.gnome.NautilusPreviewer' "${SERVICE_FILE}"
}

@test "preview-office: Brewfile no longer installs the flatpak previewer" {
    [ ! -f "${BREWFILE}" ] && false
    ! grep -q 'flatpak "org.gnome.NautilusPreviewer"' "${BREWFILE}"
}
