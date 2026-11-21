#!/usr/bin/env bats
# Tests for system_files/shared/usr/lib/systemd/system/flatpak-appstream-refresh.service
# and the .timer that starts it.
#
# The service refreshes Flatpak catalog metadata once per boot, and must skip
# the download on connections NetworkManager reports as metered. systemd
# silently ignores an ExecCondition= placed outside [Service] (#1520), so these
# tests pin both where the guard lives and what it decides.
#
# A boot target waits for the oneshot units it wants, so a WantedBy= target on
# the service held graphical.target for minutes while the refresh retried
# offline (projectbluefin/utah#1131). The timer starts it instead.
#
# Run: bats tests/test_flatpak_appstream_refresh.bats

SERVICE_FILE="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/systemd/system/flatpak-appstream-refresh.service"
TIMER_FILE="${SERVICE_FILE%.service}.timer"
PRESET_FILE="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/systemd/system-preset/02-flatpak-appstream-refresh.preset"
SYSTEM_FILES="$BATS_TEST_DIRNAME/../system_files"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# Print the values of <key>= found in [<section>] of a unit file.
section_values() {
    local file="$1" section="$2" key="$3"
    awk -v want="[${section}]" -v key="${key}=" '
        /^\[/ { in_section = ($0 == want); next }
        in_section && index($0, key) == 1 { print substr($0, length(key) + 1) }
    ' "${file}"
}

# Print the script body of the service's `ExecCondition=bash -c '<script>'`.
condition_script() {
    local value
    value="$(section_values "${SERVICE_FILE}" Service ExecCondition)"
    [[ "${value}" == "bash -c '"*"'" ]] || return 1
    value="${value#bash -c \'}"
    printf '%s\n' "${value%\'}"
}

# Run the guard with a busctl stub that answers the Metered property with
# <value>, or fails as if NetworkManager were absent when <value> is "absent".
run_condition() {
    local value="$1" script
    script="$(condition_script)"
    if [[ "${value}" == absent ]]; then
        printf '#!/bin/sh\necho "Failed to connect to bus" >&2\nexit 1\n' > "${WORKDIR}/bin/busctl"
    else
        printf '#!/bin/sh\nprintf "%%s\\n" "$*" > "%s/busctl.args"\necho "u %s"\n' \
            "${WORKDIR}" "${value}" > "${WORKDIR}/bin/busctl"
    fi
    chmod +x "${WORKDIR}/bin/busctl"
    run env PATH="${WORKDIR}/bin:${PATH}" bash -c "${script}"
}

@test "appstream refresh: metered guard is an ExecCondition in [Service], not [Unit]" {
    [ -f "${SERVICE_FILE}" ]
    [ "$(section_values "${SERVICE_FILE}" Service ExecCondition | wc -l)" -eq 1 ]
    [ -z "$(section_values "${SERVICE_FILE}" Unit ExecCondition)" ]
    [ -z "$(section_values "${SERVICE_FILE}" Install ExecCondition)" ]
    condition_script > /dev/null
}

@test "appstream refresh: guard queries NetworkManager's Metered property" {
    run_condition 2
    [ "${status}" -eq 0 ]
    [ "$(cat "${WORKDIR}/busctl.args")" = "get-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager Metered" ]
}

@test "appstream refresh: guard skips the refresh on metered connections (yes, guess-yes)" {
    local value
    for value in 1 3; do
        run_condition "${value}"
        [ "${status}" -eq 1 ]
    done
}

@test "appstream refresh: guard allows the refresh on unmetered or unknown connections" {
    local value
    for value in 0 2 4; do
        run_condition "${value}"
        [ "${status}" -eq 0 ]
    done
}

@test "appstream refresh: guard allows the refresh when NetworkManager is unavailable" {
    run_condition absent
    [ "${status}" -eq 0 ]
}

@test "appstream refresh: refresh command still runs after the guard" {
    [ "$(section_values "${SERVICE_FILE}" Service ExecStart)" = "/usr/bin/flatpak update --appstream --system --noninteractive" ]
    [ "$(section_values "${SERVICE_FILE}" Service Type)" = "oneshot" ]
}

@test "appstream refresh: no boot target pulls in the service" {
    local key
    for key in WantedBy RequiredBy UpheldBy; do
        [ -z "$(section_values "${SERVICE_FILE}" Install "${key}")" ]
    done
    # `systemctl enable flatpak-appstream-refresh.service` enables the timer.
    [ "$(section_values "${SERVICE_FILE}" Install Also)" = "flatpak-appstream-refresh.timer" ]
}

@test "appstream refresh: the timer starts the service once, after boot" {
    [ -f "${TIMER_FILE}" ]
    [ -n "$(section_values "${TIMER_FILE}" Timer OnBootSec)" ]
    # No Unit=: the timer starts the service of the same name.
    [ -z "$(section_values "${TIMER_FILE}" Timer Unit)" ]
    [ "$(section_values "${TIMER_FILE}" Install WantedBy)" = "timers.target" ]
}

@test "appstream refresh: the preset enables the timer" {
    grep -qx 'enable flatpak-appstream-refresh.timer' "${PRESET_FILE}"
}

@test "appstream refresh: preset-all links only the timer, even under a catch-all disable" {
    command -v systemctl >/dev/null || skip "systemctl is required"
    local root="${WORKDIR}/root" unitdir presetdir links
    unitdir="${root}/usr/lib/systemd/system"
    presetdir="${root}/usr/lib/systemd/system-preset"
    mkdir -p "${unitdir}" "${presetdir}" "${root}/etc"
    cp "${SERVICE_FILE}" "${TIMER_FILE}" "${unitdir}/"
    cp "${PRESET_FILE}" "${presetdir}/"
    echo 'disable *' > "${presetdir}/99-default.preset"
    run systemctl --root="${root}" preset-all
    [ "${status}" -eq 0 ]
    links="$(cd "${root}/etc/systemd/system" && find . -type l | sort)"
    [ "${links}" = "./timers.target.wants/flatpak-appstream-refresh.timer" ]
}

@test "shipped units: no Exec*= directive sits outside [Service] or [Socket]" {
    local misplaced
    # D-Bus activation files (system_files/**/dbus-1/services/*.service) also
    # carry an Exec= line, but under [D-Bus Service], not [Service]. They are
    # not systemd units, so exclude them from this systemd-unit guard.
    misplaced="$(find "${SYSTEM_FILES}" -type f \
        -not -path '*dbus-1/services/*' \
        \( -name '*.service' -o -name '*.timer' -o -name '*.socket' -o -name '*.path' -o -name '*.mount' \) \
        -exec awk '
            /^\[/ { section = $0; next }
            /^Exec[A-Za-z]*=/ && section != "[Service]" && section != "[Socket]" {
                print FILENAME ":" FNR ": " section " " $0
            }
        ' {} +)"
    if [ -n "${misplaced}" ]; then
        printf '%s\n' "${misplaced}" >&2
        false
    fi
}
