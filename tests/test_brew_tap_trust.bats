#!/usr/bin/env bats
# Regression tests for issue #814 — `brew tap --trust` is invalid syntax.
#
# `--trust` has never been a valid flag on `brew tap`. Homebrew 6.0+ rejects
# the unknown flag and exits non-zero before tapping anything, which breaks
# `ujust devmode` and the cask installers. Trust is a separate command:
#
#     brew tap   <owner>/<tap>
#     brew trust <owner>/<tap>
#
# Ref: https://docs.brew.sh/Tap-Trust
#
# Run: bats tests/test_brew_tap_trust.bats

REPO_ROOT="$BATS_TEST_DIRNAME/.."
APPS_JUST="${REPO_ROOT}/system_files/shared/usr/share/ublue-os/just/apps.just"
SYSTEM_JUST="${REPO_ROOT}/system_files/bluefin/usr/share/ublue-os/just/system.just"
BAZAAR_HOOKS="${REPO_ROOT}/system_files/bluefin/etc/bazaar/hooks.py"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    export WORKDIR
    mkdir -p "${WORKDIR}/bin"

    # Mock brew the way Homebrew 6.0 behaves: an unknown flag is a hard error.
    # A test that still passes `--trust` to `tap` therefore fails here.
    cat > "${WORKDIR}/bin/brew" << 'BREW_MOCK'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >> "${WORKDIR}/brew.log"
if [[ "$1" == "tap" ]]; then
    for arg in "$@"; do
        if [[ "${arg}" == --* ]]; then
            printf 'Error: unknown option: %s\n' "${arg}" >&2
            exit 1
        fi
    done
fi
BREW_MOCK
    chmod +x "${WORKDIR}/bin/brew"

    for cmd in sudo systemctl udevadm gum; do
        cat > "${WORKDIR}/bin/${cmd}" << MOCK
#!/usr/bin/env bash
printf '${cmd} %s\n' "\$*" >> "\${WORKDIR}/${cmd}.log"
MOCK
        chmod +x "${WORKDIR}/bin/${cmd}"
    done

    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# Assert the tap was tapped and trusted as two separate brew invocations.
_assert_tap_then_trust() {
    local tap="$1"
    grep -qx "brew tap ${tap}" "${WORKDIR}/brew.log"
    grep -qx "brew trust ${tap}" "${WORKDIR}/brew.log"
}

@test "no shipped system file passes --trust to brew tap" {
    # docs/skills/brew-lifecycle.md intentionally shows the broken form in a
    # diff block as the "don't do this" side, so only system_files is scanned.
    run grep -rn -- "tap --trust" "${REPO_ROOT}/system_files"
    [ "$status" -ne 0 ]
}

@test "bazaar hooks.py spawn_brew issues tap and trust as separate commands" {
    # spawn_brew builds a single `bash -c` string; assert on its shape.
    grep -q "brew} tap {tap}; {brew} trust {tap}" "${BAZAAR_HOOKS}"
    run grep -c -- "tap --trust" "${BAZAAR_HOOKS}"
    [ "$status" -ne 0 ]
}
