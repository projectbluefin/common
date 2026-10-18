#!/usr/bin/env bats
# Tests for the `ujust bazaar-preview` recipe in system.just.
#
# The recipe body is extracted into a standalone bash script and run against a
# fixture checkout with sudo/flatpak/systemctl/setsid mocked. The mocked sudo
# re-roots /etc/bazaar into the test's temp dir, so the install steps are
# asserted on real files without touching the host.
#
# The `source` parameter is fed in through the environment. Extraction bypasses
# just's own interpolation, so these tests cover what the recipe does with a
# checkout path, not how just passes the parameter in.

bats_require_minimum_version 1.5.0

SYSTEM_JUST="${BATS_TEST_DIRNAME}/../system_files/bluefin/usr/share/ublue-os/just/system.just"
BAZAAR_FIXTURE="${BATS_TEST_DIRNAME}/../system_files/bluefin/etc/bazaar"

_extract_recipe() {
    local recipe="$1" out_file="$2"
    awk -v recipe="$recipe" '
        $0 ~ ("^" recipe "([[:space:]$].*)?:$") { in_recipe=1; next }
        in_recipe && /^    #!\/usr\/bin\/env bash/ { found=1; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^    /, ""); print }
    ' "${SYSTEM_JUST}" \
        | sed 's|{{ *source *}}|${source}|g' > "${out_file}"
    chmod +x "${out_file}"
    [ -s "${out_file}" ]
}

_write_mock() {
    local name="$1"
    cat > "${MOCKDIR}/${name}"
    chmod +x "${MOCKDIR}/${name}"
}

setup() {
    WORKDIR="${BATS_TEST_TMPDIR}"
    MOCKDIR="${WORKDIR}/bin"
    FAKE_ROOT="${WORKDIR}/root"
    CHECKOUT="${WORKDIR}/common"
    COMMAND_LOG="${WORKDIR}/commands.log"
    mkdir -p "${MOCKDIR}" "${FAKE_ROOT}" "${CHECKOUT}/system_files/bluefin/etc/bazaar"
    : > "${COMMAND_LOG}"

    cp "${BAZAAR_FIXTURE}/bazaar.yaml" "${BAZAAR_FIXTURE}/curated.yaml" \
        "${BAZAAR_FIXTURE}/blocklist.yaml" "${BAZAAR_FIXTURE}/hooks.py" \
        "${CHECKOUT}/system_files/bluefin/etc/bazaar/"

    _extract_recipe "bazaar-preview" "${WORKDIR}/bazaar-preview.sh"

    # sudo logs its argv, treats -v as a no-op, and runs everything else with
    # destination paths under /etc/bazaar re-rooted to FAKE_ROOT.
    _write_mock "sudo" <<'MOCK'
#!/bin/bash
echo "sudo $*" >> "${COMMAND_LOG}"
[ "$1" = "-v" ] && exit 0
args=()
for a in "$@"; do
    case "$a" in /etc/bazaar*) a="${FAKE_ROOT}${a}" ;; esac
    args+=("$a")
done
exec "${args[@]}"
MOCK

    # flatpak info fails when MOCK_BAZAAR_MISSING=1 (Bazaar not installed).
    _write_mock "flatpak" <<'MOCK'
#!/bin/bash
echo "flatpak $*" >> "${COMMAND_LOG}"
[ "$1" = "info" ] && [ "${MOCK_BAZAAR_MISSING:-0}" = "1" ] && exit 1
exit 0
MOCK

    # systemctl restart fails when MOCK_RESTART_FAILS=1 so the start fallback runs.
    _write_mock "systemctl" <<'MOCK'
#!/bin/bash
echo "systemctl $*" >> "${COMMAND_LOG}"
[ "$2" = "restart" ] && [ "${MOCK_RESTART_FAILS:-0}" = "1" ] && exit 1
exit 0
MOCK

    _write_mock "setsid" <<'MOCK'
#!/bin/bash
echo "setsid $*" >> "${COMMAND_LOG}"
exit 0
MOCK

    export COMMAND_LOG FAKE_ROOT
    export PATH="${MOCKDIR}:${PATH}"
}

run_preview() {
    source="$1" run bash "${WORKDIR}/bazaar-preview.sh"
}

@test "bazaar-preview: valid checkout installs the three Bazaar YAML files" {
    run_preview "${CHECKOUT}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bazaar preview updated and launched in background."* ]]
    for f in bazaar.yaml curated.yaml blocklist.yaml; do
        cmp "${CHECKOUT}/system_files/bluefin/etc/bazaar/${f}" "${FAKE_ROOT}/etc/bazaar/${f}"
        [ "$(stat -c %a "${FAKE_ROOT}/etc/bazaar/${f}")" = "644" ]
    done
    grep -qx "sudo -v" "${COMMAND_LOG}"
    grep -qx "flatpak info io.github.kolunmi.Bazaar" "${COMMAND_LOG}"
}

@test "bazaar-preview: each missing YAML file exits 1 with usage and installs nothing" {
    for f in bazaar.yaml curated.yaml blocklist.yaml; do
        local co="${WORKDIR}/missing-${f}"
        mkdir -p "${co}/system_files/bluefin/etc/bazaar"
        cp "${CHECKOUT}/system_files/bluefin/etc/bazaar/"*.yaml "${co}/system_files/bluefin/etc/bazaar/"
        rm "${co}/system_files/bluefin/etc/bazaar/${f}"
        : > "${COMMAND_LOG}"

        run_preview "${co}"
        [ "$status" -eq 1 ]
        [[ "$output" == *"Missing ${co}/system_files/bluefin/etc/bazaar/${f}"* ]]
        [[ "$output" == *"Usage: ujust bazaar-preview /path/to/common"* ]]
        [ ! -s "${COMMAND_LOG}" ]
        [ ! -e "${FAKE_ROOT}/etc/bazaar" ]
    done
}

@test "bazaar-preview: a path that is not a common checkout is rejected before sudo" {
    run_preview "${WORKDIR}/nowhere"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing ${WORKDIR}/nowhere/system_files/bluefin/etc/bazaar/bazaar.yaml"* ]]
    run ! grep -q "^sudo" "${COMMAND_LOG}"
}

@test "bazaar-preview: Bazaar not installed aborts before anything is installed" {
    MOCK_BAZAAR_MISSING=1 run_preview "${CHECKOUT}"
    [ "$status" -ne 0 ]
    [ ! -e "${FAKE_ROOT}/etc/bazaar" ]
    run ! grep -q "^sudo install" "${COMMAND_LOG}"
    run ! grep -q "^setsid" "${COMMAND_LOG}"
}

@test "bazaar-preview: branding .jxl files are copied when bluefin-branding is present" {
    local branding="${CHECKOUT}/bluefin-branding/system_files/etc/bazaar"
    mkdir -p "${branding}"
    printf 'jxl-a' > "${branding}/banner.jxl"
    printf 'jxl-b' > "${branding}/logo.jxl"

    run_preview "${CHECKOUT}"
    [ "$status" -eq 0 ]
    cmp "${branding}/banner.jxl" "${FAKE_ROOT}/etc/bazaar/banner.jxl"
    cmp "${branding}/logo.jxl" "${FAKE_ROOT}/etc/bazaar/logo.jxl"
}

@test "bazaar-preview: no branding directory means no .jxl install" {
    run_preview "${CHECKOUT}"
    [ "$status" -eq 0 ]
    run ! grep -q '\.jxl' "${COMMAND_LOG}"
    ! compgen -G "${FAKE_ROOT}/etc/bazaar/*.jxl"
}

@test "bazaar-preview: restarts bazaar.service and launches Bazaar via setsid -f" {
    run_preview "${CHECKOUT}"
    [ "$status" -eq 0 ]
    grep -qx "systemctl --user restart bazaar.service" "${COMMAND_LOG}"
    run ! grep -q "systemctl --user start" "${COMMAND_LOG}"
    grep -qx "setsid -f flatpak run io.github.kolunmi.Bazaar" "${COMMAND_LOG}"
}

@test "bazaar-preview: falls back to starting bazaar.service when restart fails" {
    MOCK_RESTART_FAILS=1 run_preview "${CHECKOUT}"
    [ "$status" -eq 0 ]
    grep -qx "systemctl --user restart bazaar.service" "${COMMAND_LOG}"
    grep -qx "systemctl --user start bazaar.service" "${COMMAND_LOG}"
}
