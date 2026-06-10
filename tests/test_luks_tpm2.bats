#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/luks-tpm2-autounlock
#
# Strategy: source the script to load its functions (the BASH_SOURCE guard
# prevents the interactive main flow from running when sourced).
# System calls (gum, systemd-cryptenroll, sudo) are mocked via PATH.
#
# Hardware note: full TPM2 integration tests live in projectbluefin/testsuite.
# These tests cover the pure logic: UUID parsing, device resolution, error paths.
#
# Run: bats tests/test_luks_tpm2.bats

LUKS_SCRIPT="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/luks-tpm2-autounlock"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/disks" "${WORKDIR}/dev"

    # Mock gum — default: confirm/enable (exit 0)
    printf '#!/bin/bash\nexit 0\n' > "${WORKDIR}/bin/gum"
    chmod +x "${WORKDIR}/bin/gum"

    # Mock sudo — pass through to the command
    printf '#!/bin/bash\n"$@"\n' > "${WORKDIR}/bin/sudo"
    chmod +x "${WORKDIR}/bin/sudo"

    # Mock systemd-cryptenroll — records args, exits 0
    printf '#!/bin/bash\necho "cryptenroll: $*" >> %s/cryptenroll.log\nexit 0\n' "${WORKDIR}" \
        > "${WORKDIR}/bin/systemd-cryptenroll"
    chmod +x "${WORKDIR}/bin/systemd-cryptenroll"

    export PATH="${WORKDIR}/bin:${PATH}"

    # Testability overrides matching the script's env vars
    export CMDLINE_FILE="${WORKDIR}/cmdline"
    export DISK_BY_UUID_DIR="${WORKDIR}/disks"
    export DEV_DIR="${WORKDIR}/dev"

    # shellcheck source=/dev/null
    source "${LUKS_SCRIPT}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# get_luks_uuid — UUID parsing
# ---------------------------------------------------------------------------

@test "get_luks_uuid: parses rd.luks.uuid= format" {
    echo "quiet splash rd.luks.uuid=abc123-def456-7890" > "${CMDLINE_FILE}"
    result="$(get_luks_uuid)"
    [ "${result}" = "abc123-def456-7890" ]
}

@test "get_luks_uuid: strips luks- prefix from rd.luks.name= format" {
    echo "quiet splash rd.luks.name=luks-abc123-def456" > "${CMDLINE_FILE}"
    result="$(get_luks_uuid)"
    [ "${result}" = "abc123-def456" ]
}

@test "get_luks_uuid: returns first match when multiple luks entries present" {
    printf 'rd.luks.uuid=first-uuid rd.luks.uuid=second-uuid\n' > "${CMDLINE_FILE}"
    result="$(get_luks_uuid)"
    [ "${result}" = "first-uuid" ]
}

@test "get_luks_uuid: returns empty string when no luks entry present" {
    echo "quiet splash root=/dev/mapper/root" > "${CMDLINE_FILE}"
    result="$(get_luks_uuid)"
    [ -z "${result}" ]
}

# ---------------------------------------------------------------------------
# resolve_crypt_disk — device path resolution
# ---------------------------------------------------------------------------

@test "resolve_crypt_disk: returns resolved path for existing disk entry" {
    local uuid="test-uuid-1234"
    local fake_device="${WORKDIR}/dev/sda2"
    touch "${fake_device}"
    # Create the by-uuid symlink pointing to our fake device
    ln -s "${fake_device}" "${DISK_BY_UUID_DIR}/${uuid}"

    result="$(resolve_crypt_disk "${uuid}")"
    [ "${result}" = "${fake_device}" ]
}

# ---------------------------------------------------------------------------
# check_luks_device — device existence check
# ---------------------------------------------------------------------------

@test "check_luks_device: returns 0 when device found in DEV_DIR" {
    local uuid="found-uuid-5678"
    touch "${DEV_DIR}/${uuid}"
    run check_luks_device "${uuid}"
    [ "${status}" -eq 0 ]
}

@test "check_luks_device: returns 1 when device not found in DEV_DIR" {
    run check_luks_device "nonexistent-uuid-0000"
    [ "${status}" -ne 0 ]
}

@test "check_luks_device: handles empty UUID safely (uses INVALIDINVALID guard)" {
    run check_luks_device ""
    [ "${status}" -ne 0 ]
}

# ---------------------------------------------------------------------------
# End-to-end — full script with mocked commands
# ---------------------------------------------------------------------------

@test "luks: exits with error message when LUKS device not found in cmdline" {
    echo "quiet splash root=/dev/mapper/root" > "${CMDLINE_FILE}"
    # gum auto-confirms (enable path)
    run bash "${LUKS_SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Could not find LUKS device"* ]]
}

@test "luks: wipe path calls systemd-cryptenroll --wipe-slot=tpm2 (disable)" {
    local uuid="disable-uuid-abcd"
    touch "${DEV_DIR}/${uuid}"
    local fake_dev="${WORKDIR}/dev/sda2"
    touch "${fake_dev}"
    ln -s "${fake_dev}" "${DISK_BY_UUID_DIR}/${uuid}"
    echo "rd.luks.uuid=${uuid}" > "${CMDLINE_FILE}"

    # Mock gum to return 1 (Disable)
    printf '#!/bin/bash\nexit 1\n' > "${WORKDIR}/bin/gum"

    run bash "${LUKS_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "\-\-wipe-slot=tpm2" "${WORKDIR}/cryptenroll.log"
    # Must NOT pass --tpm2-device (disable path only wipes)
    ! grep -q "\-\-tpm2-device" "${WORKDIR}/cryptenroll.log"
}

@test "luks: enroll path calls systemd-cryptenroll with tpm2-device (enable, no pin)" {
    local uuid="enable-uuid-efgh"
    touch "${DEV_DIR}/${uuid}"
    local fake_dev="${WORKDIR}/dev/sdb2"
    touch "${fake_dev}"
    ln -s "${fake_dev}" "${DISK_BY_UUID_DIR}/${uuid}"
    echo "rd.luks.uuid=${uuid}" > "${CMDLINE_FILE}"

    # gum: first call (Toggle) returns 0 (Enable), second call (PIN) returns 1 (No PIN)
    call_count=0
    printf '#!/bin/bash\ncount_file=%s/gum_calls\ncount=$(($(cat "${count_file}" 2>/dev/null || echo 0) + 1))\necho "${count}" > "${count_file}"\nif [ "${count}" -eq 2 ]; then exit 1; fi\nexit 0\n' \
        "${WORKDIR}" > "${WORKDIR}/bin/gum"

    run bash "${LUKS_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "\-\-tpm2-device=auto" "${WORKDIR}/cryptenroll.log"
}

@test "luks: enroll with PIN passes --tpm2-with-pin=yes" {
    local uuid="pin-uuid-ijkl"
    touch "${DEV_DIR}/${uuid}"
    local fake_dev="${WORKDIR}/dev/sdc2"
    touch "${fake_dev}"
    ln -s "${fake_dev}" "${DISK_BY_UUID_DIR}/${uuid}"
    echo "rd.luks.uuid=${uuid}" > "${CMDLINE_FILE}"

    # gum: both calls return 0 (Enable + Yes to PIN)
    printf '#!/bin/bash\nexit 0\n' > "${WORKDIR}/bin/gum"

    run bash "${LUKS_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "\-\-tpm2-with-pin=yes" "${WORKDIR}/cryptenroll.log"
}
