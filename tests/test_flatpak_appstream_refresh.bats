#!/usr/bin/env bats
# Tests for system_files/shared/usr/lib/systemd/system/flatpak-appstream-refresh.service
#
# The service refreshes Flatpak catalog metadata on every boot, and must skip
# the download on connections NetworkManager reports as metered. systemd
# silently ignores an ExecCondition= placed outside [Service] (#1520), so these
# tests pin both where the guard lives and what it decides.
#
# Run: bats tests/test_flatpak_appstream_refresh.bats

SERVICE_FILE="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/systemd/system/flatpak-appstream-refresh.service"
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

@test "shipped units: no Exec*= directive sits outside [Service] or [Socket]" {
    local misplaced
    misplaced="$(find "${SYSTEM_FILES}" -type f \
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
