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
BAZAAR_HOOK="${REPO_ROOT}/system_files/bluefin/usr/libexec/bazaar-hook"

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

@test "install-jetbrains-toolbox taps then trusts ublue-os/tap" {
    run just --justfile "${APPS_JUST}" --working-directory "${WORKDIR}" install-jetbrains-toolbox
    [ "$status" -eq 0 ]
    _assert_tap_then_trust "ublue-os/tap"
    run grep -c -- "--trust" "${WORKDIR}/brew.log"
    [ "$status" -ne 0 ]
}

@test "install-jetbrains-toolbox still installs the cask after trusting" {
    run just --justfile "${APPS_JUST}" --working-directory "${WORKDIR}" install-jetbrains-toolbox
    [ "$status" -eq 0 ]
    grep -qx "brew install --cask ublue-os/tap/jetbrains-toolbox-linux" "${WORKDIR}/brew.log"
}

@test "install-asus taps then trusts ublue-os/tap without aborting the recipe" {
    run just --justfile "${APPS_JUST}" --working-directory "${WORKDIR}" install-asus
    [ "$status" -eq 0 ]
    _assert_tap_then_trust "ublue-os/tap"
    grep -qx "brew install --cask ublue-os/tap/asusctl-linux" "${WORKDIR}/brew.log"
    grep -qx "brew install --cask ublue-os/tap/rog-control-center-linux" "${WORKDIR}/brew.log"
}

@test "install-asus survives a tap that already exists under set -euo pipefail" {
    # A second run exercises the "tap already tapped" path: brew errors, and
    # the `|| true` guard must keep the pipefail recipe alive.
    cat > "${WORKDIR}/bin/brew" << 'BREW_MOCK'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >> "${WORKDIR}/brew.log"
if [[ "$1" == "tap" || "$1" == "trust" ]]; then
    printf 'Error: Tap already installed\n' >&2
    exit 1
fi
BREW_MOCK
    chmod +x "${WORKDIR}/bin/brew"

    run just --justfile "${APPS_JUST}" --working-directory "${WORKDIR}" install-asus
    [ "$status" -eq 0 ]
    grep -qx "brew install --cask ublue-os/tap/asusctl-linux" "${WORKDIR}/brew.log"
}

@test "system.just dx tap block taps then trusts both taps" {
    # Extract just the tap/trust lines from the dx recipe and run them, so the
    # test does not need to drive the whole interactive gum menu.
    sed -n '/# Taps are silent\/fast/,/^$/p' "${SYSTEM_JUST}" \
        | sed -e 's/_dx_wants[^;]*;/true;/' > "${WORKDIR}/dx-taps.sh"
    grep -q "brew tap ublue-os/tap" "${WORKDIR}/dx-taps.sh"
    grep -q "brew trust ublue-os/tap" "${WORKDIR}/dx-taps.sh"
    grep -q "brew tap ublue-os/experimental-tap" "${WORKDIR}/dx-taps.sh"
    grep -q "brew trust ublue-os/experimental-tap" "${WORKDIR}/dx-taps.sh"

    {
        printf '%s\n' '#!/usr/bin/env bash'
        printf '%s\n' 'set -euo pipefail'
        printf '%s\n' '_dx_wants() { return 0; }'
        sed -e 's/^    //' "${WORKDIR}/dx-taps.sh"
    } > "${WORKDIR}/dx-taps-run.sh"
    chmod +x "${WORKDIR}/dx-taps-run.sh"

    run "${WORKDIR}/dx-taps-run.sh"
    [ "$status" -eq 0 ]
    _assert_tap_then_trust "ublue-os/tap"
    _assert_tap_then_trust "ublue-os/experimental-tap"
}

@test "bazaar-hook spawn_brew issues tap and trust as separate commands" {
    # spawn_brew builds a single `bash -c` string; assert on its shape.
    grep -q "brew} tap ublue-os/tap" "${BAZAAR_HOOK}"
    grep -q "brew} trust ublue-os/tap" "${BAZAAR_HOOK}"
    run grep -c -- "tap --trust" "${BAZAAR_HOOK}"
    [ "$status" -ne 0 ]
}
