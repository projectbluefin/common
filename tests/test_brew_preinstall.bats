#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/brew-preinstall
#
# Strategy: patch the three hardcoded absolute paths in the script to
# temp-dir equivalents so tests run without root or real Homebrew.
# The mock brew's shellenv subcommand adds the mock bin dir to PATH so
# subsequent `brew` calls (bundle, list, uninstall) all hit the mock.
# HOME is overridden so STATE_FILE lands in a writable temp dir.
#
# Run: bats tests/test_brew_preinstall.bats

BREW_PREINSTALL="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/brew-preinstall"
WORKDIR=""
PATCHED_SCRIPT=""

setup() {
    WORKDIR="$(mktemp -d)"
    export WORKDIR

    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/preinstall.d"

    # Override HOME so STATE_FILE lands in a writable location
    export HOME="${WORKDIR}"

    # Brew mock: shellenv adds our mock bin dir to PATH so `brew bundle` etc.
    # all hit this stub and not any real brew on the system.
    cat > "${WORKDIR}/bin/brew" << BREWMOCK
#!/usr/bin/env bash
BREW_LOG="\${BREW_LOG:-/dev/null}"
printf 'brew %s\n' "\$*" >> "\${BREW_LOG}"
case "\$1" in
    shellenv)
        printf 'export PATH="%s:\${PATH}"\n' "${WORKDIR}/bin"
        ;;
    bundle)
        ;;
    list)
        exit 0
        ;;
    uninstall)
        ;;
esac
BREWMOCK
    chmod +x "${WORKDIR}/bin/brew"

    # Patch hardcoded paths in the script to temp-dir equivalents
    PATCHED_SCRIPT="${WORKDIR}/brew-preinstall"
    sed \
        -e "s|/var/home/linuxbrew/.linuxbrew/bin/brew|${WORKDIR}/bin/brew|g" \
        -e "s|/usr/share/ublue-os/homebrew/preinstall.d|${WORKDIR}/preinstall.d|g" \
        "${BREW_PREINSTALL}" > "${PATCHED_SCRIPT}"
    chmod +x "${PATCHED_SCRIPT}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# Early-exit guards
# ---------------------------------------------------------------------------

@test "brew-preinstall: exits 0 with message when brew is not found" {
    rm -f "${WORKDIR}/bin/brew"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"brew not found"* ]]
}

@test "brew-preinstall: exits 0 with message when preinstall.d does not exist" {
    rm -rf "${WORKDIR}/preinstall.d"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"no preinstall.d"* ]]
}

@test "brew-preinstall: exits 0 with message when preinstall.d contains no Brewfiles" {
    # directory exists but is empty

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"no Brewfiles"* ]]
}

# ---------------------------------------------------------------------------
# Hash-unchanged fast path
# ---------------------------------------------------------------------------

@test "brew-preinstall: fast-exits when Brewfile hash is unchanged" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    expected_hash="$(cat "${WORKDIR}/preinstall.d/system-cli.Brewfile" | sha256sum | cut -d' ' -f1)"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"%s","packages":["ripgrep"]}' "${expected_hash}" \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"nothing to do"* ]]
    ! grep -q "brew bundle" "${WORKDIR}/brew.log" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Hash-changed: install path
# ---------------------------------------------------------------------------

@test "brew-preinstall: runs brew bundle when Brewfiles have changed" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Brewfiles changed"* ]]
    grep -q "brew bundle" "${WORKDIR}/brew.log"
}

@test "brew-preinstall: passes --file and --no-lock to brew bundle" {
    echo 'brew "fd"' > "${WORKDIR}/preinstall.d/tools.Brewfile"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "\-\-no-lock" "${WORKDIR}/brew.log"
    grep -q "\-\-file=" "${WORKDIR}/brew.log"
}

@test "brew-preinstall: runs brew bundle for each Brewfile" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/a.Brewfile"
    echo 'brew "fd"'      > "${WORKDIR}/preinstall.d/b.Brewfile"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    bundle_count="$(grep -c "brew bundle" "${WORKDIR}/brew.log" || true)"
    [ "${bundle_count}" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Package removal — packages dropped from Brewfile are uninstalled
# ---------------------------------------------------------------------------

@test "brew-preinstall: uninstalls package removed from managed set" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    # Simulate old state that also had fd (now dropped)
    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["fd","ripgrep"]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "brew uninstall" "${WORKDIR}/brew.log"
    grep -q "fd" "${WORKDIR}/brew.log"
}

@test "brew-preinstall: does not uninstall package still in Brewfile" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["ripgrep"]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -q "brew uninstall" "${WORKDIR}/brew.log" 2>/dev/null
}

@test "brew-preinstall: skips uninstall for package not installed by brew" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["fd","ripgrep"]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    # Override brew mock: list returns 1 (not installed)
    cat > "${WORKDIR}/bin/brew" << BREWMOCK
#!/usr/bin/env bash
BREW_LOG="\${BREW_LOG:-/dev/null}"
printf 'brew %s\n' "\$*" >> "\${BREW_LOG}"
case "\$1" in
    shellenv) printf 'export PATH="%s:\${PATH}"\n' "${WORKDIR}/bin" ;;
    bundle)   ;;
    list)     exit 1 ;;
    uninstall) ;;
esac
BREWMOCK
    chmod +x "${WORKDIR}/bin/brew"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -q "brew uninstall" "${WORKDIR}/brew.log" 2>/dev/null
}

# ---------------------------------------------------------------------------
# State file — written atomically via tmp + mv
# ---------------------------------------------------------------------------

@test "brew-preinstall: writes state file after successful run" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json" ]
}

@test "brew-preinstall: state file contains hash and package list after run" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]

    state_file="${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
    [ -f "${state_file}" ]
    stored_hash="$(jq -r '.hash' "${state_file}")"
    [ -n "${stored_hash}" ]
    pkgs="$(jq -r '.packages[]' "${state_file}")"
    [[ "${pkgs}" == *"ripgrep"* ]]
}

@test "brew-preinstall: does not leave a .tmp state file after run" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ ! -f "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json.tmp" ]
}

@test "brew-preinstall: re-runs after Brewfile changes (hash mismatch)" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    # First run — sets state
    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"complete"* ]]

    # Change Brewfile — hash changes
    echo 'brew "fd"' >> "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    BREW_LOG="${WORKDIR}/brew2.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Brewfiles changed"* ]]
    grep -q "brew bundle" "${WORKDIR}/brew2.log"
}
