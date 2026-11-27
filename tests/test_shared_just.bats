#!/usr/bin/env bats
# Tests for system_files/shared/usr/share/ublue-os/just/shared.just
#
# Covers toggle-tpm2 (LUKS TPM2 auto-unlock toggle).
SHARED_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/shared.just"
WORKDIR=""

# Extract a shebang recipe body from shared.just and dedent it by four spaces.
_extract_recipe() {
    awk -v name="$1" '
        $0 == name ":" { in_recipe = 1; next }
        in_recipe && $0 ~ /^[^[:space:]]/ { exit }
        in_recipe && $0 ~ /^    / { sub(/^    /, ""); print }
        in_recipe && $0 == "" { print }
    ' "${SHARED_JUST}"
}

    SHARED_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/shared.just"
    [ -f "${SHARED_JUST}" ]

teardown() {
    rm -rf "${WORKDIR}"
}

@test "toggle-tpm2: invokes the absolute luks-tpm2-autounlock path" {
    run grep -A2 '^toggle-tpm2:' "${SHARED_JUST}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"/usr/bin/luks-tpm2-autounlock"* ]]
}

@test "shared.just: recipes are grouped under System" {
    [ "$(grep -c "^\[group('System')\]" "${SHARED_JUST}")" -eq 1 ]
}
