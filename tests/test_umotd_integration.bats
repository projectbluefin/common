#!/usr/bin/env bats
# Tests for umotd integration after migration from legacy ublue-motd:
#   - system_files/shared/etc/profile.d/umotd.sh
#   - system_files/shared/usr/share/fish/vendor_conf.d/fish_greeting.fish
#   - toggle-user-motd just recipe in default.just
#
# Key behavioral contract: opt-out logic (formerly ~/.config/no-show-user-motd)
# is now fully delegated to umotd itself. Neither profile.d nor fish_greeting
# should check for that file or gate the umotd invocation.
#
# Run: bats tests/test_umotd_integration.bats

bats_require_minimum_version 1.5.0

UMOTD_PROFILE="${BATS_TEST_DIRNAME}/../system_files/shared/etc/profile.d/umotd.sh"
FISH_GREETING="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/fish/vendor_conf.d/fish_greeting.fish"
DEFAULT_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/default.just"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/home/.config"

    # Mock umotd — exits 0, records args to a log
    printf '#!/usr/bin/env bash\necho "umotd $*" >> "%s/umotd.log"\n' \
        "${WORKDIR}" > "${WORKDIR}/bin/umotd"
    chmod +x "${WORKDIR}/bin/umotd"

    export HOME="${WORKDIR}/home"
    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# profile.d/umotd.sh — bash/zsh terminal MOTD
# ---------------------------------------------------------------------------

@test "umotd.sh: invokes umotd" {
    run bash "${UMOTD_PROFILE}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/umotd.log" ]
}

@test "umotd.sh: invokes umotd even when no-show-user-motd opt-out file exists" {
    # Opt-out is now inside umotd itself — profile.d must NOT gate on this file
    touch "${HOME}/.config/no-show-user-motd"
    run bash "${UMOTD_PROFILE}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/umotd.log" ]
}

@test "umotd.sh: does not contain no-show-user-motd check" {
    run grep 'no-show-user-motd' "${UMOTD_PROFILE}"
    [ "${status}" -ne 0 ]
}

@test "umotd.sh: does not call legacy ublue-motd" {
    run grep 'ublue-motd' "${UMOTD_PROFILE}"
    [ "${status}" -ne 0 ]
}

# ---------------------------------------------------------------------------
# fish_greeting.fish — fish terminal MOTD (static content checks)
# Fish is not required in CI; these are grep-based structural assertions.
# ---------------------------------------------------------------------------

@test "fish_greeting: function body calls umotd" {
    grep -q 'umotd' "${FISH_GREETING}"
}

@test "fish_greeting: does not check no-show-user-motd (opt-out delegated to umotd)" {
    run grep 'no-show-user-motd' "${FISH_GREETING}"
    [ "${status}" -ne 0 ]
}

@test "fish_greeting: does not call legacy ublue-motd" {
    run grep 'ublue-motd' "${FISH_GREETING}"
    [ "${status}" -ne 0 ]
}

# ---------------------------------------------------------------------------
# toggle-user-motd just recipe
# ---------------------------------------------------------------------------

@test "toggle-user-motd: recipe delegates to umotd toggle" {
    grep -A5 '^toggle-user-motd:' "${DEFAULT_JUST}" | grep -q 'umotd toggle'
}

@test "toggle-user-motd: recipe no longer contains legacy gum logic" {
    local recipe
    recipe="$(grep -A20 '^toggle-user-motd:' "${DEFAULT_JUST}")"
    [[ "${recipe}" != *'gum confirm'* ]]
}

@test "toggle-user-motd: recipe no longer manipulates no-show-user-motd file" {
    local recipe
    recipe="$(grep -A20 '^toggle-user-motd:' "${DEFAULT_JUST}")"
    [[ "${recipe}" != *'no-show-user-motd'* ]]
}
