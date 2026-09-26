#!/usr/bin/env bats
# Tests for Damask Flatpak overrides, tmpfiles configuration, and systemd user service.
#
# Covers:
# - Flatpak sandbox override permissions and configuration
# - tmpfiles.d symlink rule syntax and pattern parity with Bazaar
# - Systemd user service unit definition, condition flags, and ordering
# - Systemd unit validation via systemd-analyze verify

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/.."
    OVERRIDE_FILE="$REPO_ROOT/system_files/bluefin/usr/share/ublue-os/flatpak-overrides/app.drey.Damask"
    TMPFILES_FILE="$REPO_ROOT/system_files/bluefin/usr/lib/tmpfiles.d/damask-flatpak.conf"
    SERVICE_FILE="$REPO_ROOT/system_files/bluefin/usr/lib/systemd/user/damask.service"
    BAZAAR_TMPFILES="$REPO_ROOT/system_files/bluefin/usr/lib/tmpfiles.d/bazaar-flatpak.conf"
    WORKDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "damask flatpak override: file exists and specifies backgrounds filesystems" {
    [ -f "${OVERRIDE_FILE}" ]
    grep -Fxq "[Context]" "${OVERRIDE_FILE}"
    grep -Fxq "filesystems=host-os:ro;xdg-data/backgrounds:ro;" "${OVERRIDE_FILE}"
}

@test "damask tmpfiles: configuration exists and defines valid symlink override" {
    [ -f "${TMPFILES_FILE}" ]
    local expected="L /var/lib/flatpak/overrides/app.drey.Damask - - - - /usr/share/ublue-os/flatpak-overrides/app.drey.Damask"
    local actual
    actual="$(grep -v '^[[:space:]]*#' "${TMPFILES_FILE}" | grep -v '^[[:space:]]*$' | tr -s ' ')"
    [ "${actual}" = "${expected}" ]

    # Verify parity with Bazaar's tmpfiles pattern
    [ -f "${BAZAAR_TMPFILES}" ]
    local bazaar_type
    bazaar_type="$(awk '{print $1}' "${BAZAAR_TMPFILES}")"
    local damask_type
    damask_type="$(awk '{print $1}' "${TMPFILES_FILE}")"
    [ "${damask_type}" = "${bazaar_type}" ]
    [ "${damask_type}" = "L" ]

    # Validate tmpfiles format: 7 columns (Type Path Mode UID GID Age Argument)
    local col_count
    col_count="$(awk 'NF > 0 {print NF}' "${TMPFILES_FILE}")"
    [ "${col_count}" -eq 7 ]
}

@test "damask service: unit exists and specifies correct condition flags and lifecycle" {
    [ -f "${SERVICE_FILE}" ]
    grep -Fxq "Description=Damask Wallpaper Slideshow Background Service" "${SERVICE_FILE}"
    grep -Fxq "After=graphical-session.target" "${SERVICE_FILE}"
    grep -Fxq "ConditionUser=!@system" "${SERVICE_FILE}"
    grep -Fxq "ConditionPathExists=|%h/.local/share/flatpak/app/app.drey.Damask" "${SERVICE_FILE}"
    grep -Fxq "ConditionPathExists=|/var/lib/flatpak/app/app.drey.Damask" "${SERVICE_FILE}"
    grep -Fxq "Type=simple" "${SERVICE_FILE}"
    grep -Fxq "ExecStart=/usr/bin/flatpak run app.drey.Damask --background" "${SERVICE_FILE}"
    grep -Fxq "Restart=on-failure" "${SERVICE_FILE}"
    grep -Fxq "RestartSec=10" "${SERVICE_FILE}"
    grep -Fxq "WantedBy=graphical-session.target" "${SERVICE_FILE}"
}

@test "damask service: ConditionPathExists uses disjunction for user and system flatpak paths" {
    local conditions
    conditions="$(grep '^ConditionPathExists=' "${SERVICE_FILE}")"
    local count
    count="$(printf '%s\n' "${conditions}" | grep -c '^ConditionPathExists=|')"
    [ "${count}" -eq 2 ]

    printf '%s\n' "${conditions}" | grep -q '|%h/\.local/share/flatpak/app/app\.drey\.Damask'
    printf '%s\n' "${conditions}" | grep -q '|/var/lib/flatpak/app/app\.drey\.Damask'
}

@test "damask service: systemd-analyze verify validates unit structure and ordering" {
    if ! command -v systemd-analyze >/dev/null 2>&1; then
        skip "systemd-analyze not available in environment"
    fi

    local unit_dir="${WORKDIR}/systemd-user"
    mkdir -p "${unit_dir}"

    sed 's|ExecStart=/usr/bin/flatpak run app.drey.Damask --background|ExecStart=/bin/true|' \
        "${SERVICE_FILE}" > "${unit_dir}/damask.service"

    cat > "${unit_dir}/graphical-session.target" <<'EOF'
[Unit]
Description=Test graphical session
StopWhenUnneeded=yes
EOF

    run env \
        SYSTEMD_LOG_LEVEL=debug \
        SYSTEMD_UNIT_PATH="${unit_dir}:/usr/lib/systemd/system" \
        systemd-analyze verify \
        graphical-session.target \
        damask.service
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"After: graphical-session.target"* ]]
    [[ "${output}" != *"ordering cycle"* ]]
}
