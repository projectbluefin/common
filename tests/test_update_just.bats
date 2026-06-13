#!/usr/bin/env bats
# Tests for update.just and toggle-updates recipes

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
    ' "${UPDATE_JUST}" > "${out_file}"
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
    mkdir -p "${MOCKDIR}"
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
text = text.replace("/var/home/linuxbrew/.linuxbrew/bin/brew", "${MOCK_BREW_BIN:-/var/home/linuxbrew/.linuxbrew/bin/brew}")
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

    for cmd in bootc; do
        cat > "${MOCKDIR}/${cmd}" <<MOCK
#!/bin/bash
echo "${cmd} \$*" >> "\${COMMAND_LOG}"
MOCK
        chmod +x "${MOCKDIR}/${cmd}"
    done

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
        MOCK_HAS_UUPD_TIMER="${MOCK_HAS_UUPD_TIMER:-0}" \
        MOCK_ACTIVE_SERVICE="${MOCK_ACTIVE_SERVICE:-}" \
        MOCK_ENABLED_TIMER="${MOCK_ENABLED_TIMER:-}" \
        MOCK_FLATPAK_REMOTES="${MOCK_FLATPAK_REMOTES:-}" \
        MOCK_GUM_CHOICE="${MOCK_GUM_CHOICE:-}" \
        MOCK_HAS_LAYERED_PACKAGES="${MOCK_HAS_LAYERED_PACKAGES:-0}" \
        MOCK_BREW_BIN="${MOCK_BREW_BIN:-${WORKDIR}/missing-brew}" \
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
    grep -qF "sudo bootc upgrade" "${COMMAND_LOG}"
    ! grep -qF "rpm-ostree upgrade" "${COMMAND_LOG}"
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

@test "toggle-updates: enables uupd.timer when present and Enable chosen" {
    MOCK_HAS_UUPD_TIMER=1 MOCK_GUM_CHOICE="Enable" _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qF "systemctl enable uupd.timer" "${COMMAND_LOG}"
}

@test "toggle-updates: disables rpm-ostreed timer when uupd absent and Disable chosen" {
    MOCK_GUM_CHOICE="Disable" _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qF "systemctl disable rpm-ostreed-automatic.timer" "${COMMAND_LOG}"
}

@test "toggle-updates: exits cleanly on Cancel" {
    MOCK_GUM_CHOICE="Cancel" _run "${TOGGLE_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -qF "systemctl enable" "${COMMAND_LOG}"
    ! grep -qF "systemctl disable" "${COMMAND_LOG}"
}
