#!/usr/bin/env bats
# Tests for update.just and toggle-updates recipes

bats_require_minimum_version 1.5.0

UPDATE_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/update.just"
WORKDIR=""
MOCKDIR=""
COMMAND_LOG=""
UPDATE_SCRIPT=""
TOGGLE_SCRIPT=""

_extract_script() {
    local recipe="$1" out_file="$2"
    awk -v recipe="$recipe" '
        $0 ~ ("^" recipe "([[:space:]].*)?:$") { in_recipe=1; next }
        in_recipe && /^    #!\/usr\/bin\/bash/ { found=1; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^    /, ""); print }
    ' "${UPDATE_JUST}" \
        | sed 's/{{ ACTION }}/${ACTION:-prompt}/g' > "${out_file}"
}

_write_mock() {
    local name="$1"
    cat > "${MOCKDIR}/${name}"
    chmod +x "${MOCKDIR}/${name}"
}

setup() {
    WORKDIR="${BATS_TEST_DIRNAME}/.test-update-just-${BATS_TEST_NUMBER}-$$"
    rm -rf "${WORKDIR}"
    mkdir -p "${WORKDIR}"

    MOCKDIR="${WORKDIR}/bin"
    COMMAND_LOG="${WORKDIR}/commands.log"
    SYSTEMD_STATE="${WORKDIR}/systemd-state"
    mkdir -p "${MOCKDIR}" "${SYSTEMD_STATE}"
    : > "${COMMAND_LOG}"

    UPDATE_SCRIPT="${WORKDIR}/update.sh"
    TOGGLE_SCRIPT="${WORKDIR}/toggle-updates.sh"
    _extract_script "update" "${UPDATE_SCRIPT}"
    _extract_script "toggle-updates" "${TOGGLE_SCRIPT}"
    python - <<'PY2' "${UPDATE_SCRIPT}"
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
text = text.replace("/home/linuxbrew/.linuxbrew/bin/brew", "${MOCK_BREW_BIN:-/home/linuxbrew/.linuxbrew/bin/brew}")
p.write_text(text)
PY2
    chmod +x "${UPDATE_SCRIPT}" "${TOGGLE_SCRIPT}"

    _write_mock "systemctl" <<'MOCK'
#!/bin/bash
echo "systemctl $*" >> "${COMMAND_LOG}"
case "$1" in
    cat)
        [[ "$3" == "uupd.timer" && "${MOCK_HAS_UUPD_TIMER:-0}" == "1" ]] && exit 0 || exit 1
        ;;
    is-active)
        [[ "${3:-$2}" == "${MOCK_ACTIVE_SERVICE:-}" ]] && exit 0 || exit 1
        ;;
    is-enabled)
        [[ "${3:-$2}" == "${MOCK_ENABLED_TIMER:-}" ]] && exit 0 || exit 1
        ;;
    enable|disable)
        verb="$1"
        now=0
        shift
        if [[ "${1:-}" == "--now" ]]; then
            now=1
            shift
        fi
        for unit in "$@"; do
            if [[ "${verb}" == "enable" ]]; then
                touch "${SYSTEMD_STATE}/${unit}.enabled"
                [[ "${now}" == "1" ]] && touch "${SYSTEMD_STATE}/${unit}.active"
            else
                rm -f "${SYSTEMD_STATE}/${unit}.enabled"
                [[ "${now}" == "1" ]] && rm -f "${SYSTEMD_STATE}/${unit}.active"
            fi
        done
        exit 0
        ;;
    start)
        shift
        for unit in "$@"; do
            touch "${SYSTEMD_STATE}/${unit}.active"
        done
        exit 0
        ;;
    stop)
        shift
        for unit in "$@"; do
            rm -f "${SYSTEMD_STATE}/${unit}.active"
        done
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
MOCK

    _write_mock "sudo" <<'MOCK'
#!/bin/bash
echo "sudo $*" >> "${COMMAND_LOG}"
exec "$@"
MOCK

    _write_mock "bootc" <<'MOCK'
#!/bin/bash
echo "bootc $*" >> "${COMMAND_LOG}"
if [[ "${MOCK_BOOTC_STATUS:-0}" != "0" ]]; then
    echo "mock bootc upgrade failure" >&2
fi
exit "${MOCK_BOOTC_STATUS:-0}"
MOCK

    # An installed copy must never take over the native recipes.
    _write_mock "bctl" <<'MOCK'
#!/bin/bash
echo "unexpected bctl invocation" >&2
exit 99
MOCK

    _write_mock "rpm-ostree" <<'MOCK'
#!/bin/bash
echo "rpm-ostree $*" >> "${COMMAND_LOG}"
if [[ "$1" == "status" && "$2" == "--booted" ]]; then
    if [[ "${MOCK_HAS_LAYERED_PACKAGES:-0}" == "1" ]]; then
        printf 'State: idle\nDeployments:\n* fedora:fedora/40/x86_64/silverblue\n  Layered packages: howdy\n'
    else
        printf 'State: idle\nDeployments:\n* fedora:fedora/40/x86_64/silverblue\n'
    fi
fi
MOCK

    _write_mock "flatpak" <<'MOCK'
#!/bin/bash
echo "flatpak $*" >> "${COMMAND_LOG}"
if [[ "$1" == "remotes" ]]; then
    printf '%s\n' "${MOCK_FLATPAK_REMOTES:-}"
fi
MOCK

    _write_mock "gum" <<'MOCK'
#!/bin/bash
if [[ "$1" == "choose" ]]; then
    printf '%s\n' "${MOCK_GUM_CHOICE:-}"
fi
MOCK

    _write_mock "grep" <<'MOCK'
#!/bin/bash
exec /usr/bin/grep "$@"
MOCK

    chmod -R a+rwX "${WORKDIR}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

_run() {
    run env \
        PATH="${MOCKDIR}:${PATH}" \
        COMMAND_LOG="${COMMAND_LOG}" \
        SYSTEMD_STATE="${SYSTEMD_STATE}" \
        MOCK_BOOTC_STATUS="${MOCK_BOOTC_STATUS:-0}" \
        MOCK_HAS_UUPD_TIMER="${MOCK_HAS_UUPD_TIMER:-0}" \
        MOCK_ACTIVE_SERVICE="${MOCK_ACTIVE_SERVICE:-}" \
        MOCK_ENABLED_TIMER="${MOCK_ENABLED_TIMER:-}" \
        MOCK_FLATPAK_REMOTES="${MOCK_FLATPAK_REMOTES:-}" \
        MOCK_GUM_CHOICE="${MOCK_GUM_CHOICE:-}" \
        MOCK_HAS_LAYERED_PACKAGES="${MOCK_HAS_LAYERED_PACKAGES:-0}" \
        MOCK_BREW_BIN="${MOCK_BREW_BIN:-${WORKDIR}/missing-brew}" \
        ACTION="${ACTION:-prompt}" \
        bash "$@"
}

@test "update: uses uupd.service when uupd.timer is present" {
    MOCK_HAS_UUPD_TIMER=1 _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qF "systemctl is-active --quiet uupd.service" "${COMMAND_LOG}"
}

@test "update: falls back to rpm-ostreed-automatic.service when uupd.timer absent" {
    _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qF "systemctl is-active --quiet rpm-ostreed-automatic.service" "${COMMAND_LOG}"
}

@test "update: exits early when update service is active" {
    MOCK_HAS_UUPD_TIMER=1 MOCK_ACTIVE_SERVICE="uupd.service" _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"automatic updates are currently running"* ]]
    ! grep -qF "bootc upgrade" "${COMMAND_LOG}"
}

@test "update: runs bootc upgrade when no layered packages are present" {
    _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Starting OS image update"* ]]
    grep -qF "sudo bootc upgrade" "${COMMAND_LOG}"
    ! grep -qF "rpm-ostree upgrade" "${COMMAND_LOG}"
}

@test "update: preserves bootc failure and diagnostics without running package updates" {
    _write_mock "brew" <<'MOCK'
#!/bin/bash
echo "brew $*" >> "${COMMAND_LOG}"
MOCK
    MOCK_BOOTC_STATUS=42 MOCK_FLATPAK_REMOTES=$'system\nuser' \
        MOCK_BREW_BIN="${MOCKDIR}/brew" _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 42 ]
    [[ "${output}" == *"mock bootc upgrade failure"* ]]
    run ! grep -qE '^(flatpak|brew) ' "${COMMAND_LOG}"
}

@test "update: updates both flatpak scopes and user-owned brew after bootc succeeds" {
    _write_mock "brew" <<'MOCK'
#!/bin/bash
echo "brew $*" >> "${COMMAND_LOG}"
MOCK
    MOCK_FLATPAK_REMOTES=$'system\nuser' MOCK_BREW_BIN="${MOCKDIR}/brew" _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qF "flatpak update -y" "${COMMAND_LOG}"
    grep -qF "flatpak update --user -y" "${COMMAND_LOG}"
    grep -qFx "brew upgrade" "${COMMAND_LOG}"
}

@test "update: exits early with layered-packages warning when rpm-ostree has layered packages" {
    MOCK_HAS_LAYERED_PACKAGES=1 _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Status: Layered Packages Detected"* ]]
    [[ "${output}" == *"rpm-ostree reset"* ]]
    ! grep -qF "sudo bootc upgrade" "${COMMAND_LOG}"
}

@test "update: updates system flatpaks when system remote exists" {
    MOCK_FLATPAK_REMOTES=$'system' _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qF "flatpak update -y" "${COMMAND_LOG}"
    ! grep -qF "flatpak update --user -y" "${COMMAND_LOG}"
}

@test "update: updates user flatpaks when user remote exists" {
    MOCK_FLATPAK_REMOTES=$'user' _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qF "flatpak update --user -y" "${COMMAND_LOG}"
    ! grep -qF "flatpak update -y" "${COMMAND_LOG}"
}

@test "update: skips flatpak when no remotes exist" {
    _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -qF "flatpak update" "${COMMAND_LOG}"
}

@test "update: skips brew when binary is absent" {
    _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -qF "brew upgrade" "${COMMAND_LOG}"
}

@test "toggle-updates: interactive Enable enables both uupd timers, starts only uupd.timer" {
    MOCK_HAS_UUPD_TIMER=1 MOCK_GUM_CHOICE="Enable" _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -e "${SYSTEMD_STATE}/uupd.timer.enabled" ]
    [ -e "${SYSTEMD_STATE}/uupd.timer.active" ]
    [ -e "${SYSTEMD_STATE}/uupd-resume.timer.enabled" ]
    [ ! -e "${SYSTEMD_STATE}/uupd-resume.timer.active" ]
}

@test "toggle-updates: legacy disable cancels its timer and enable reactivates it" {
    touch "${SYSTEMD_STATE}/rpm-ostreed-automatic.timer.active" \
        "${SYSTEMD_STATE}/rpm-ostreed-automatic.service.active" \
        "${SYSTEMD_STATE}/uupd-resume.timer.active"
    MOCK_GUM_CHOICE="Disable" _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ ! -e "${SYSTEMD_STATE}/rpm-ostreed-automatic.timer.active" ]
    [ -e "${SYSTEMD_STATE}/rpm-ostreed-automatic.service.active" ]
    [ -e "${SYSTEMD_STATE}/uupd-resume.timer.active" ]
    ACTION=enable _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -e "${SYSTEMD_STATE}/rpm-ostreed-automatic.timer.active" ]
    [ -e "${SYSTEMD_STATE}/rpm-ostreed-automatic.service.active" ]
    [ -e "${SYSTEMD_STATE}/uupd-resume.timer.active" ]
}

@test "toggle-updates: exits cleanly on Cancel" {
    MOCK_GUM_CHOICE="Cancel" _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -qF "systemctl enable" "${COMMAND_LOG}"
    ! grep -qF "systemctl disable" "${COMMAND_LOG}"
}

@test "toggle-updates: ACTION=cancel exits without touching the timer" {
    ACTION=cancel _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -qF "systemctl enable" "${COMMAND_LOG}"
    ! grep -qF "systemctl disable" "${COMMAND_LOG}"
}

@test "toggle-updates: ACTION is case-insensitive (ENABLE enables uupd timers)" {
    MOCK_HAS_UUPD_TIMER=1 ACTION=ENABLE _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -e "${SYSTEMD_STATE}/uupd.timer.active" ]
    [ -e "${SYSTEMD_STATE}/uupd-resume.timer.enabled" ]
    [ ! -e "${SYSTEMD_STATE}/uupd-resume.timer.active" ]
}

# Regression contract for projectbluefin/common#1516: disabling cancels armed
# timer triggers without stopping an update service that is already running.
@test "toggle-updates: disabling and enabling uupd preserves a running updater" {
    touch "${SYSTEMD_STATE}/uupd.timer.active" \
        "${SYSTEMD_STATE}/uupd-resume.timer.active" \
        "${SYSTEMD_STATE}/uupd.service.active"
    MOCK_HAS_UUPD_TIMER=1 ACTION=disable _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Updates have been disabled"* ]]
    ! [[ "${output}" == *"Automatic updates are currently"* ]]
    [ ! -e "${SYSTEMD_STATE}/uupd.timer.active" ]
    [ ! -e "${SYSTEMD_STATE}/uupd-resume.timer.active" ]
    [ -e "${SYSTEMD_STATE}/uupd.service.active" ]
    MOCK_HAS_UUPD_TIMER=1 ACTION=enable _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Updates have been enabled"* ]]
    ! [[ "${output}" == *"Automatic updates are currently"* ]]
    [ -e "${SYSTEMD_STATE}/uupd.timer.active" ]
    # uupd-resume.timer is enabled for the next resume but not armed now.
    [ -e "${SYSTEMD_STATE}/uupd-resume.timer.enabled" ]
    [ ! -e "${SYSTEMD_STATE}/uupd-resume.timer.active" ]
    [ -e "${SYSTEMD_STATE}/uupd.service.active" ]
}

@test "uupd-on-ac: switch-off skips cleanly but wait failures remain errors" {
    local unit="${BATS_TEST_DIRNAME}/../system_files/shared/usr/lib/systemd/system/uupd-on-ac.service"
    local enabled="${WORKDIR}/ac-enabled" delayed="${WORKDIR}/ac-delayed"
    _write_mock "systemctl" <<'MOCK'
#!/bin/bash
[[ "$1" == "is-enabled" ]] || exit 99
[[ -e "${AC_ENABLED_FILE}" ]]
MOCK
    _write_mock "sleep" <<'MOCK'
#!/bin/bash
touch "${AC_DELAYED_FILE}"
if [[ "${AC_WAIT_EXIT:-0}" != "0" ]]; then
    exit "${AC_WAIT_EXIT}"
fi
rm -f "${AC_ENABLED_FILE}"
MOCK
    cat > "${WORKDIR}/ac-condition.py" <<'PY'
import configparser
import os
from pathlib import Path
import shlex
import subprocess
import sys

unit = configparser.ConfigParser(interpolation=None)
unit.read(sys.argv[1])
command = shlex.split(unit["Service"]["ExecCondition"])
replacements = {
    "/usr/bin/systemctl": str(Path(sys.argv[2]) / "systemctl"),
    "/bin/sleep": str(Path(sys.argv[2]) / "sleep"),
}
for index, argument in enumerate(command):
    if argument in replacements:
        command[index] = replacements[argument]
    else:
        for original, replacement in replacements.items():
            argument = argument.replace(original, shlex.quote(replacement))
        command[index] = argument
raise SystemExit(subprocess.run(command, env=os.environ, check=False).returncode)
PY
    touch "${enabled}"
    run env AC_ENABLED_FILE="${enabled}" AC_DELAYED_FILE="${delayed}" \
        python3 "${WORKDIR}/ac-condition.py" "${unit}" "${MOCKDIR}"
    # ExecCondition exit 1 means a skipped start, not a failed service.
    [ "${status}" -eq 1 ]
    [ -e "${delayed}" ]
    [ ! -e "${enabled}" ]
    touch "${enabled}"
    run env AC_ENABLED_FILE="${enabled}" AC_DELAYED_FILE="${delayed}" \
        AC_WAIT_EXIT=42 python3 "${WORKDIR}/ac-condition.py" "${unit}" "${MOCKDIR}"
    # ExecCondition exit 255 preserves a real execution failure.
    [ "${status}" -eq 255 ]
    [ -e "${enabled}" ]
}

# Regression contract for projectbluefin/common#1332:
# `bootc upgrade` must be invoked as a plain verb. Adding --transport
# containers-storage (or any explicit transport) would force the broken
# `pull_unified` path even when the image is not in bootc storage, and
# adding --unified-storage / --soft-reboot / --apply would change the
# staged-deployment semantics that `bootc-update-stage` and ChairLift
# rely on. The recipe may also chain `|| exit $?]` after the verb —
# that is just-error handling, not a bootc flag.
@test "update: invokes plain 'sudo bootc upgrade' with no extra bootc flags (issue #1332)" {
    # Static check on the recipe: tokenize each line that runs the bootc verb
    # and reject any actual bootc flag (a token starting with `--`).
    run bash -c '
        set -euo pipefail
        bad=0
        while IFS= read -r line; do
            case "${line}" in
                *"sudo bootc upgrade"*)
                    # Take everything after the bare verb.
                    tail="${line##*sudo bootc upgrade}"
                    # Drop just-recipe error handling / terminators / comments.
                    tail="${tail%%||*}"
                    tail="${tail%%]*}"
                    tail="${tail%%#*}"
                    # Any whitespace-separated token starting with "--" is a
                    # bootc flag; that is the regression we are guarding.
                    for tok in ${tail}; do
                        case "${tok}" in
                            --*)
                                echo "REJECTED flag '${tok}' in: '${line}'" >&2
                                bad=1
                                ;;
                        esac
                    done
                    ;;
            esac
        done < "$1"
        exit "${bad}"
    ' _ "${UPDATE_JUST}"
    [ "${status}" -eq 0 ]

    # End-to-end: the recipe passes the bare verb to the bootc mock.
    _run "${UPDATE_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qFx "sudo bootc upgrade" "${COMMAND_LOG}"
}
