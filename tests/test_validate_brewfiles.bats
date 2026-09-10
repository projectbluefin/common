#!/usr/bin/env bats
# All commands use a fake brew, never the host's package manager.
bats_require_minimum_version 1.5.0

setup() {
    WORKDIR=$(mktemp -d)
    ROOT="${BATS_TEST_DIRNAME}/.."
    SCRIPT="${ROOT}/scripts/validate-brewfiles.sh"
    export FIXTURES="${WORKDIR}/Brewfiles with spaces"
    export CALLS="${WORKDIR}/calls" TAPS="${WORKDIR}/taps"
    export TMPDIR="${WORKDIR}/scratch"
    mkdir -p "${FIXTURES}" "${TMPDIR}" "${WORKDIR}/bin"
    touch "${CALLS}"
    cat > "${WORKDIR}/bin/brew" <<'MOCK'
#!/bin/bash
printf '%s|%s|%s\n' "${1:-}" "${2:-}" "${@: -1}" >> "${CALLS}"
case "$1" in
    bundle)
        cp "${2#--file=}" "${TAPS}"
        if [[ "${MOCK_TAP_STATUS:-0}" != 0 ]]; then
            echo 'tap stdout diagnostic'
            echo 'tap stderr: authentication/network/trust error' >&2
            exit "${MOCK_TAP_STATUS}"
        fi
        ;;
    info)
        [[ $# -eq 4 && "$3" == -- ]] || exit 99
        case " ${MOCK_INFO_FAILURES:-} " in
            *" $4 "*)
                echo 'metadata stdout diagnostic'
                echo "${MOCK_INFO_ERROR:-metadata stderr: cask unavailable}" >&2
                exit 42
                ;;
        esac
        ;;
    *) echo "unexpected brew operation: $*" >&2; exit 99 ;;
esac
MOCK
    chmod +x "${WORKDIR}/bin/brew"
    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "validator checks formulas and casks recursively with source lines" {
    mkdir "${FIXTURES}/nested"
    printf '  brew "ripgrep" # comment\n' > "${FIXTURES}/nested/test.Brewfile"
    echo "  cask 'demo', args: { no_quarantine: true }" >> "${FIXTURES}/nested/test.Brewfile"
    run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"test.Brewfile:1: formula ripgrep"* ]]
    [[ "${output}" == *"test.Brewfile:2: cask demo"* ]]
    [[ "${output}" == *"1 Brewfiles, 2 package checks, 0 failures"* ]]
    grep -qFx 'info|--formula|ripgrep' "${CALLS}"
    grep -qFx 'info|--cask|demo' "${CALLS}"
    [ ! -e "${TAPS}" ]
}

@test "validator syncs all declared taps before any package checks" {
    printf 'tap "one/tap", trusted: true\ncask "one/tap/demo"\n' > "${FIXTURES}/a.Brewfile"
    printf 'tap "two/tap", trusted: true\ntap "one/tap", trusted: true\n' > "${FIXTURES}/z.Brewfile"
    run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 0 ]
    grep -qFx 'tap "one/tap", trusted: true' "${TAPS}"
    grep -qFx 'tap "two/tap", trusted: true' "${TAPS}"
    [ "$(wc -l < "${TAPS}")" -eq 2 ]
    [[ "$(head -1 "${CALLS}")" == bundle\|* ]]
    run ! grep -qE '^[[:space:]]*(brew|cask) ' "${TAPS}"
}

@test "tap failure is fatal and preserves both output streams" {
    printf 'tap "broken/tap", trusted: true\ncask "demo"\n' > "${FIXTURES}/test.Brewfile"
    MOCK_TAP_STATUS=17 run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"tap setup (exit 17)"* ]]
    [[ "${output}" == *"Package checks were not run"* ]]
    [[ "${output}" == *"Command: brew bundle"* ]]
    [[ "${output}" == *"broken/tap"* ]]
    [[ "${output}" == *"tap stdout diagnostic"* ]]
    [[ "${output}" == *"tap stderr: authentication/network/trust error"* ]]
    run ! grep -q '^info|' "${CALLS}"
}

@test "cask failure reports file line command exit code and original error" {
    printf '# heading\ncask "missing"\n' > "${FIXTURES}/test.Brewfile"
    MOCK_INFO_FAILURES=missing run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"${FIXTURES}/test.Brewfile:2: cask missing (exit 42)"* ]]
    [[ "${output}" == *"Command: brew info --cask -- missing"* ]]
    [[ "${output}" == *"metadata stdout diagnostic"* ]]
    [[ "${output}" == *"metadata stderr: cask unavailable"* ]]
    [[ "${output}" == *"1 package checks, 1 failures"* ]]
}

@test "ambiguity is not mislabeled as a missing tap" {
    echo 'cask "wallpapers"' > "${FIXTURES}/test.Brewfile"
    MOCK_INFO_FAILURES=wallpapers MOCK_INFO_ERROR='Cask wallpapers exists in multiple taps: frostyard/tap, ublue-os/tap' \
        run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"exists in multiple taps: frostyard/tap, ublue-os/tap"* ]]
    [[ "${output}" != *"invalid or missing tap"* ]]
}

@test "validator reports every failure and continues through later files" {
    printf 'cask "missing"\nbrew "ripgrep"\n' > "${FIXTURES}/a.Brewfile"
    printf 'brew "other"\ncask "good"\n' > "${FIXTURES}/z.Brewfile"
    MOCK_INFO_FAILURES='missing other' run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"2 Brewfiles, 4 package checks, 2 failures"* ]]
    grep -qFx 'info|--formula|ripgrep' "${CALLS}"
    grep -qFx 'info|--cask|good' "${CALLS}"
}

@test "validator checks final declaration without newline and ignores comments and flatpaks" {
    printf '# cask "ignored"\nflatpak "org.example.App"\nbrew "ripgrep"' > "${FIXTURES}/test.Brewfile"
    run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 0 ]
    [ "$(wc -l < "${CALLS}")" -eq 1 ]
    grep -qFx 'info|--formula|ripgrep' "${CALLS}"
}

@test "malformed and computed declarations fail instead of disappearing" {
    printf 'brew "missing-close\ncask package_name\nbrew "good"\ncask(package_name)\n' > "${FIXTURES}/test.Brewfile"
    run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"test.Brewfile:1: expected a quoted literal"* ]]
    [[ "${output}" == *"test.Brewfile:2: expected a quoted literal"* ]]
    [[ "${output}" == *"test.Brewfile:4: expected a quoted literal"* ]]
    [[ "${output}" == *"1 package checks, 3 failures"* ]]
}

# The malicious command substitution must stay literal in both fixture and assertion.
# shellcheck disable=SC2016
@test "package names are passed as data and never evaluated as shell code" {
    printf 'cask "$(touch %s/pwned)"\n' "${WORKDIR}" > "${FIXTURES}/test.Brewfile"
    run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 0 ]
    [ ! -e "${WORKDIR}/pwned" ]
    grep -qF 'info|--cask|$(touch ' "${CALLS}"
}

@test "validator fails for nonexistent or empty directories and invalid arguments" {
    run bash "${SCRIPT}" "${WORKDIR}/missing"
    [ "${status}" -eq 2 ]
    run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"No Brewfiles found"* ]]
    run bash "${SCRIPT}" one two
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Usage:"* ]]
    [ ! -s "${CALLS}" ]
}

@test "validator reports missing Homebrew before running any commands" {
    rm "${WORKDIR}/bin/brew"
    run /usr/bin/env PATH="${WORKDIR}/bin" /bin/bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Homebrew is required"* ]]
}

@test "validator cleans scratch files on success and failure" {
    echo 'cask "missing"' > "${FIXTURES}/test.Brewfile"
    run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 0 ]
    [ -z "$(ls -A "${TMPDIR}")" ]
    MOCK_INFO_FAILURES=missing run bash "${SCRIPT}" "${FIXTURES}"
    [ "${status}" -eq 1 ]
    [ -z "$(ls -A "${TMPDIR}")" ]
}

@test "repository artwork and Zed use the intended unambiguous cask names" {
    local shared="${ROOT}/system_files/shared/usr/share/ublue-os/homebrew"
    local name
    for name in aurora-wallpapers bazzite-wallpapers bluefin-wallpapers bluefin-wallpapers-extra framework-wallpapers; do
        grep -qFx "cask \"ublue-os/tap/${name}\"" "${shared}/artwork.Brewfile"
    done
    grep -qFx 'cask "ublue-os/tap/zed-linux"' "${shared}/experimental-ide.Brewfile"
    grep -qFx 'tap "ublue-os/tap", trusted: true' "${shared}/experimental-ide.Brewfile"
    run ! grep -q 'ublue-os/experimental-tap/zed-linux' "${shared}/experimental-ide.Brewfile"
}
