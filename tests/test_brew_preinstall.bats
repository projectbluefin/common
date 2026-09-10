#!/usr/bin/env bats
# Tests for system_files/shared/usr/libexec/brew-preinstall,
# its /usr/bin wrapper, and its systemd user unit.
#
# Strategy: patch the hardcoded absolute paths in the libexec script to
# temp-dir equivalents so tests run without root or real Homebrew.
# The mock brew's shellenv subcommand adds the mock bin dir to PATH so
# subsequent `brew` calls (bundle, list, uninstall) all hit the mock.
# HOME is overridden so STATE_FILE lands in a writable temp dir.
#
# Run: bats tests/test_brew_preinstall.bats

bats_require_minimum_version 1.5.0

BREW_PREINSTALL="$BATS_TEST_DIRNAME/../system_files/shared/usr/libexec/brew-preinstall"
BREW_PREINSTALL_WRAPPER="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/brew-preinstall"
BREW_PREINSTALL_SERVICE="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/systemd/user/brew-preinstall.service"
BREW_PREINSTALL_PRESET="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/systemd/user-preset/01-brew-preinstall.preset"
UBLUE_USER_SETUP_SERVICE="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/systemd/user/ublue-user-setup.service"
WORKDIR=""
PATCHED_SCRIPT=""
PATCHED_WRAPPER=""

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
        -e "s|/home/linuxbrew/.linuxbrew/bin/brew|${WORKDIR}/bin/brew|g" \
        -e "s|/usr/share/ublue-os/homebrew/preinstall.d|${WORKDIR}/preinstall.d|g" \
        "${BREW_PREINSTALL}" > "${PATCHED_SCRIPT}"
    chmod +x "${PATCHED_SCRIPT}"

    PATCHED_WRAPPER="${WORKDIR}/brew-preinstall-wrapper"
    sed \
        -e "s|/usr/libexec/brew-preinstall|${PATCHED_SCRIPT}|g" \
        "${BREW_PREINSTALL_WRAPPER}" > "${PATCHED_WRAPPER}"
    chmod +x "${PATCHED_WRAPPER}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# Systemd integration
# ---------------------------------------------------------------------------

@test "brew-preinstall service: runs after the graphical session with reduced resource priority" {
    grep -Fxq \
        "After=ublue-user-setup.service graphical-session.target" \
        "${BREW_PREINSTALL_SERVICE}"
    grep -Fxq "Slice=background.slice" "${BREW_PREINSTALL_SERVICE}"
    grep -Fxq "IOWeight=10" "${BREW_PREINSTALL_SERVICE}"
    local unit_section service_section
    unit_section="$(sed -n '/^\[Unit\]$/,/^\[Service\]$/p' "${BREW_PREINSTALL_SERVICE}")"
    service_section="$(sed -n '/^\[Service\]$/,/^\[Install\]$/p' "${BREW_PREINSTALL_SERVICE}")"
    [[ "${unit_section}" == *"StartLimitBurst=3"* ]]
    [[ "${service_section}" != *"StartLimitBurst="* ]]
    grep -Fxq "WantedBy=graphical-session.target" "${BREW_PREINSTALL_SERVICE}"
    ! grep -q "network-online.target" "${BREW_PREINSTALL_SERVICE}"
    ! grep -q "network-online.target" "${UBLUE_USER_SETUP_SERVICE}"
}

@test "brew-preinstall service: preset delivery and systemd transaction preserve ordering" {
    local unit_dir="${WORKDIR}/systemd-user"
    mkdir -p "${unit_dir}/graphical-session.target.wants"
    # Verify with a standalone system-manager transaction because CI has no
    # user manager. Target/Wants/After ordering semantics are identical.
    sed 's|ExecStart=/usr/bin/brew-preinstall|ExecStart=/bin/true|' \
        "${BREW_PREINSTALL_SERVICE}" > "${unit_dir}/brew-preinstall.service"
    sed 's|ExecStart=/usr/bin/ublue-user-setup|ExecStart=/bin/true|' \
        "${UBLUE_USER_SETUP_SERVICE}" > "${unit_dir}/ublue-user-setup.service"
    ln -s ../brew-preinstall.service \
        "${unit_dir}/graphical-session.target.wants/brew-preinstall.service"

    cat > "${unit_dir}/graphical-session.target" <<'EOF'
[Unit]
Description=Test graphical session
StopWhenUnneeded=yes
EOF

    grep -Fxq "enable brew-preinstall.service" "${BREW_PREINSTALL_PRESET}"

    run env \
        SYSTEMD_LOG_LEVEL=debug \
        SYSTEMD_UNIT_PATH="${unit_dir}:/usr/lib/systemd/system" \
        systemd-analyze verify \
        graphical-session.target \
        brew-preinstall.service \
        ublue-user-setup.service
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Before: brew-preinstall.service"* ]]
    [[ "${output}" == *"After: graphical-session.target"* ]]
    [[ "${output}" != *"ordering cycle"* ]]
    [[ "${output}" != *"Unit network-online.target not found"* ]]
}

# ---------------------------------------------------------------------------
# Wrapper
# ---------------------------------------------------------------------------

@test "brew-preinstall wrapper: delegates to libexec implementation" {
    run bash "${PATCHED_WRAPPER}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"no Brewfiles"* ]]
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

@test "brew-preinstall: passes --file to brew bundle" {
    echo 'brew "fd"' > "${WORKDIR}/preinstall.d/tools.Brewfile"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
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

@test "brew-preinstall: repository manifests remove previously managed bluefinctl" {
    cp "${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/"*.Brewfile \
        "${WORKDIR}/preinstall.d/"
    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["bluefinctl"],"casks":[]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q '^brew uninstall bluefinctl --ignore-dependencies$' "${WORKDIR}/brew.log"
    run ! grep -q 'bluefinctl' "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
    run ! grep -q '^brew tap .*bluefinctl' "${WORKDIR}/brew.log"
}

@test "brew-preinstall: repository manifests leave untracked installs alone" {
    cp "${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/"*.Brewfile \
        "${WORKDIR}/preinstall.d/"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    run ! grep -q '^brew uninstall ' "${WORKDIR}/brew.log"
    run ! grep -q 'bluefinctl' "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
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

# ---------------------------------------------------------------------------
# Cask lifecycle
# ---------------------------------------------------------------------------

@test "brew-preinstall: handles cask-only Brewfile without aborting" {
    echo 'cask "chairlift"' > "${WORKDIR}/preinstall.d/chairlift.Brewfile"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"complete"* ]]
}

@test "brew-preinstall: tracks casks in state file" {
    echo 'cask "chairlift"' > "${WORKDIR}/preinstall.d/chairlift.Brewfile"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]

    state_file="${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
    [ -f "${state_file}" ]
    casks="$(jq -r '.casks[]' "${state_file}")"
    [[ "${casks}" == *"chairlift"* ]]
}

@test "brew-preinstall: uninstalls cask removed from managed set" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["ripgrep"],"casks":["chairlift"]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "brew uninstall --cask" "${WORKDIR}/brew.log"
    grep -q "chairlift" "${WORKDIR}/brew.log"
}

@test "brew-preinstall: does not uninstall cask still in Brewfile" {
    echo 'cask "chairlift"' > "${WORKDIR}/preinstall.d/chairlift.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":[],"casks":["chairlift"]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -q "brew uninstall --cask" "${WORKDIR}/brew.log" 2>/dev/null
}

@test "brew-preinstall: skips uninstall for cask not installed by brew" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["ripgrep"],"casks":["chairlift"]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    # Override brew mock: list --cask returns 1 (not installed)
    cat > "${WORKDIR}/bin/brew" << BREWMOCK
#!/usr/bin/env bash
BREW_LOG="\${BREW_LOG:-/dev/null}"
printf 'brew %s\n' "\$*" >> "\${BREW_LOG}"
case "\$1" in
    shellenv) printf 'export PATH="%s:\${PATH}"\n' "${WORKDIR}/bin" ;;
    bundle)   ;;
    list)
        if [[ "\$*" == *"--cask"* ]]; then
            exit 1
        fi
        exit 0
        ;;
    uninstall) ;;
esac
BREWMOCK
    chmod +x "${WORKDIR}/bin/brew"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -q "brew uninstall --cask" "${WORKDIR}/brew.log" 2>/dev/null
}

@test "brew-preinstall: handles legacy state file without casks key" {
    echo 'cask "chairlift"' > "${WORKDIR}/preinstall.d/chairlift.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":[]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"complete"* ]]
}

@test "brew-preinstall: handles mixed brew and cask Brewfiles" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/formulas.Brewfile"
    echo 'cask "chairlift"' > "${WORKDIR}/preinstall.d/casks.Brewfile"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"complete"* ]]

    state_file="${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
    pkgs="$(jq -r '.packages[]' "${state_file}")"
    [[ "${pkgs}" == *"ripgrep"* ]]
    casks="$(jq -r '.casks[]' "${state_file}")"
    [[ "${casks}" == *"chairlift"* ]]
}

@test "brew-preinstall: accepts indented single-quoted cask declarations" {
    echo "  cask 'chairlift'" > "${WORKDIR}/preinstall.d/apps.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":[],"casks":["chairlift"]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -q "uninstall --cask chairlift" "${WORKDIR}/brew.log" 2>/dev/null
    jq -e '.casks == ["chairlift"]' \
        "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
}

@test "brew-preinstall: accepts indented single-quoted formula declarations" {
    echo "  brew 'ripgrep'" > "${WORKDIR}/preinstall.d/tools.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["ripgrep"],"casks":[]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -q "uninstall ripgrep" "${WORKDIR}/brew.log" 2>/dev/null
    jq -e '.packages == ["ripgrep"]' \
        "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
}

@test "brew-preinstall: renaming a cask from tap-qualified to bare does not uninstall it" {
    echo 'cask "chairlift"' > "${WORKDIR}/preinstall.d/apps.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":[],"casks":["frostyard/tap/chairlift"]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"removing cask frostyard/tap/chairlift"* ]]
    ! grep -q "uninstall --cask" "${WORKDIR}/brew.log" 2>/dev/null
    jq -e '.casks == ["chairlift"]' \
        "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
}

@test "brew-preinstall: renaming a formula from tap-qualified to bare does not uninstall it" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/tools.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["homebrew/core/ripgrep"],"casks":[]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"removing homebrew/core/ripgrep"* ]]
    ! grep -q "uninstall homebrew/core/ripgrep" "${WORKDIR}/brew.log" 2>/dev/null
    jq -e '.packages == ["ripgrep"]' \
        "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
}

@test "brew-preinstall: cask removal does not touch formula with same diff" {
    echo 'brew "chairlift-formula"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["chairlift-formula"],"casks":["chairlift"]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "uninstall --cask chairlift" "${WORKDIR}/brew.log"
    ! grep -q "uninstall chairlift-formula" "${WORKDIR}/brew.log" 2>/dev/null
}

@test "brew-preinstall: state file has empty casks array when no cask lines" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]

    state_file="${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"
    [ "$(jq '.casks | length' "${state_file}")" -eq 0 ]
}

@test "brew-preinstall: one failing Brewfile does not block the others" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/a-fail.Brewfile"
    echo 'brew "fd"' > "${WORKDIR}/preinstall.d/b-ok.Brewfile"

    cat > "${WORKDIR}/bin/brew" << BREWMOCK
#!/usr/bin/env bash
BREW_LOG="\${BREW_LOG:-/dev/null}"
printf 'brew %s\n' "\$*" >> "\${BREW_LOG}"
case "\$1" in
    shellenv) printf 'export PATH="%s:\${PATH}"\n' "${WORKDIR}/bin" ;;
    bundle)
        if [[ "\$*" == *"a-fail"* ]]; then
            exit 1
        fi
        ;;
    list)     exit 0 ;;
    uninstall) ;;
esac
BREWMOCK
    chmod +x "${WORKDIR}/bin/brew"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    grep -q "b-ok.Brewfile" "${WORKDIR}/brew.log"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"will retry"* ]]
    [ ! -f "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json" ]
    ! grep -q "uninstall" "${WORKDIR}/brew.log" 2>/dev/null
}

@test "brew-preinstall: bundle failure skips removals entirely" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["fd","ripgrep"],"casks":[]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    cat > "${WORKDIR}/bin/brew" << BREWMOCK
#!/usr/bin/env bash
BREW_LOG="\${BREW_LOG:-/dev/null}"
printf 'brew %s\n' "\$*" >> "\${BREW_LOG}"
case "\$1" in
    shellenv) printf 'export PATH="%s:\${PATH}"\n' "${WORKDIR}/bin" ;;
    bundle)   exit 1 ;;
    list)     exit 0 ;;
    uninstall) ;;
esac
BREWMOCK
    chmod +x "${WORKDIR}/bin/brew"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 1 ]
    ! grep -q "uninstall" "${WORKDIR}/brew.log" 2>/dev/null
    stored_hash="$(jq -r '.hash' "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json")"
    [ "${stored_hash}" = "oldhash" ]
}

@test "brew-preinstall: corrupt state file warns, skips removals, rebuilds state" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    echo 'not json at all {{' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"state file is corrupt"* ]]
    ! grep -q "uninstall" "${WORKDIR}/brew.log" 2>/dev/null
    jq -e . "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json" >/dev/null
}

@test "brew-preinstall: failed uninstall keeps old state so removal is retried" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    mkdir -p "${WORKDIR}/.local/share/ublue-os"
    printf '{"hash":"oldhash","packages":["fd","ripgrep"],"casks":[]}' \
        > "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json"

    cat > "${WORKDIR}/bin/brew" << BREWMOCK
#!/usr/bin/env bash
BREW_LOG="\${BREW_LOG:-/dev/null}"
printf 'brew %s\n' "\$*" >> "\${BREW_LOG}"
case "\$1" in
    shellenv) printf 'export PATH="%s:\${PATH}"\n' "${WORKDIR}/bin" ;;
    bundle)   ;;
    list)     exit 0 ;;
    uninstall)
        echo "mock uninstall failure" >&2
        exit 1
        ;;
esac
BREWMOCK
    chmod +x "${WORKDIR}/bin/brew"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"removals failed"* ]]
    [[ "${output}" == *"mock uninstall failure"* ]]
    stored_hash="$(jq -r '.hash' "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json")"
    [ "${stored_hash}" = "oldhash" ]
    pkgs="$(jq -r '.packages[]' "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json")"
    [[ "${pkgs}" == *"fd"* ]]
}

@test "brew-preinstall: taps all Brewfile taps before any bundle runs" {
    printf 'tap "frostyard/tap", trusted: true\ncask "chairlift"\n' \
        > "${WORKDIR}/preinstall.d/chairlift.Brewfile"
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "^brew tap frostyard/tap$" "${WORKDIR}/brew.log"
    first_bundle=$(grep -n "^brew bundle" "${WORKDIR}/brew.log" | head -1 | cut -d: -f1)
    tap_line=$(grep -n "^brew tap frostyard/tap$" "${WORKDIR}/brew.log" | head -1 | cut -d: -f1)
    [ "${tap_line}" -lt "${first_bundle}" ]
}

@test "brew-preinstall: skipped cask marks the run failed so it retries" {
    printf 'tap "frostyard/tap", trusted: true\ncask "chairlift"\n' \
        > "${WORKDIR}/preinstall.d/chairlift.Brewfile"

    cat > "${WORKDIR}/bin/brew" << BREWMOCK
#!/usr/bin/env bash
BREW_LOG="\${BREW_LOG:-/dev/null}"
printf 'brew %s\n' "\$*" >> "\${BREW_LOG}"
case "\$1" in
    shellenv) printf 'export PATH="%s:\${PATH}"\n' "${WORKDIR}/bin" ;;
    bundle)   echo "Skipping cask chairlift (requires macOS)" ;;
    list)     exit 0 ;;
    uninstall) ;;
esac
BREWMOCK
    chmod +x "${WORKDIR}/bin/brew"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"skipped a cask"* ]]
    [ ! -f "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json" ]
}

@test "brew-preinstall: failed tap aborts before bundling and leaves state unstamped" {
    printf 'tap "frostyard/tap", trusted: true\ncask "chairlift"\n' \
        > "${WORKDIR}/preinstall.d/chairlift.Brewfile"

    cat > "${WORKDIR}/bin/brew" << BREWMOCK
#!/usr/bin/env bash
BREW_LOG="\${BREW_LOG:-/dev/null}"
printf 'brew %s\n' "\$*" >> "\${BREW_LOG}"
case "\$1" in
    shellenv) printf 'export PATH="%s:\${PATH}"\n' "${WORKDIR}/bin" ;;
    tap)      exit 1 ;;
    list)     exit 0 ;;
esac
BREWMOCK
    chmod +x "${WORKDIR}/bin/brew"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"will retry"* ]]
    ! grep -q "^brew bundle" "${WORKDIR}/brew.log"
    [ ! -f "${WORKDIR}/.local/share/ublue-os/brew-preinstall-state.json" ]
}

@test "brew-preinstall: bundle output surfaces in the run output" {
    echo 'brew "ripgrep"' > "${WORKDIR}/preinstall.d/system-cli.Brewfile"

    cat > "${WORKDIR}/bin/brew" << BREWMOCK
#!/usr/bin/env bash
BREW_LOG="\${BREW_LOG:-/dev/null}"
printf 'brew %s\n' "\$*" >> "\${BREW_LOG}"
case "\$1" in
    shellenv) printf 'export PATH="%s:\${PATH}"\n' "${WORKDIR}/bin" ;;
    bundle)   echo "BUNDLE-OUTPUT-MARKER" ;;
    list)     exit 0 ;;
    uninstall) ;;
esac
BREWMOCK
    chmod +x "${WORKDIR}/bin/brew"

    BREW_LOG="${WORKDIR}/brew.log" run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"BUNDLE-OUTPUT-MARKER"* ]]
}

@test "brew-preinstall: never references /dev/stderr (ENXIO under systemd)" {
    ! sed 's/#.*//' "${BREW_PREINSTALL}" | grep -q "/dev/stderr"
}
