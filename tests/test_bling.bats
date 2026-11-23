#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/ublue-bling
#
# Run: bats tests/test_bling.bats

BLING_SCRIPT="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ublue-bling"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    # Mock gum — default: auto-confirm (exit 0)
    mkdir -p "${WORKDIR}/bin"
    printf '#!/bin/bash\nexit 0\n' > "${WORKDIR}/bin/gum"
    chmod +x "${WORKDIR}/bin/gum"
    export PATH="${WORKDIR}/bin:${PATH}"

    # Use an isolated BLING_CLI_DIRECTORY so tests don't require /usr/share
    export BLING_CLI_DIRECTORY="${WORKDIR}/bling"
    mkdir -p "${BLING_CLI_DIRECTORY}"
    printf '# mock bling.sh\n' > "${BLING_CLI_DIRECTORY}/bling.sh"
    printf '# mock bling.fish\n' > "${BLING_CLI_DIRECTORY}/bling.fish"

    # Skip env.sh sourcing
    export BLING_ENV_SCRIPT="${WORKDIR}/env.sh"
    printf '# mock env\n' > "${BLING_ENV_SCRIPT}"

    # Isolated home directory — unset XDG_CONFIG_HOME so the script uses
    # the HOME-based fallback rather than the CI runner's real XDG path
    export HOME="${WORKDIR}/home"
    unset XDG_CONFIG_HOME
    mkdir -p "${HOME}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# Install — bash
# ---------------------------------------------------------------------------

@test "ublue-bling: bash install creates sentinel block in .bashrc" {
    export SHELL="/bin/bash"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${HOME}/.bashrc" ]
    grep -qF "### bling.sh source start" "${HOME}/.bashrc"
    grep -qF "### bling.sh source end" "${HOME}/.bashrc"
}

@test "ublue-bling: bash install writes source line in .bashrc" {
    export SHELL="/bin/bash"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qF "source ${BLING_CLI_DIRECTORY}/bling.sh" "${HOME}/.bashrc"
}

# ---------------------------------------------------------------------------
# Install — zsh
# ---------------------------------------------------------------------------

@test "ublue-bling: zsh install creates sentinel block in .zshrc" {
    export SHELL="/bin/zsh"
    export ZDOTDIR="${HOME}"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${HOME}/.zshrc" ]
    grep -qF "### bling.sh source start" "${HOME}/.zshrc"
}

# ---------------------------------------------------------------------------
# Install — fish
# ---------------------------------------------------------------------------

@test "ublue-bling: fish install creates sentinel block in config.fish" {
    mkdir -p "${HOME}/.config/fish"
    export SHELL="/bin/fish"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${HOME}/.config/fish/config.fish" ]
    grep -qF "### bling.fish source start" "${HOME}/.config/fish/config.fish"
}

# ---------------------------------------------------------------------------
# Uninstall (idempotency)
# ---------------------------------------------------------------------------

@test "ublue-bling: second run uninstalls (removes sentinel block)" {
    export SHELL="/bin/bash"
    # First run: install
    bash "${BLING_SCRIPT}"
    grep -qF "### bling.sh source start" "${HOME}/.bashrc"

    # Second run: detect installed → gum confirm to uninstall → sed removes block
    run bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -qF "### bling.sh source start" "${HOME}/.bashrc"
}

@test "ublue-bling: no duplicate block on repeated install-uninstall-install" {
    export SHELL="/bin/bash"
    bash "${BLING_SCRIPT}"   # install
    bash "${BLING_SCRIPT}"   # uninstall
    bash "${BLING_SCRIPT}"   # reinstall
    block_count="$(grep -cF "### bling.sh source start" "${HOME}/.bashrc" || echo 0)"
    [ "${block_count}" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Decline / cancel
# ---------------------------------------------------------------------------

@test "ublue-bling: declining install (gum exits 1) does not modify .bashrc" {
    export SHELL="/bin/bash"
    # Mock gum to decline
    printf '#!/bin/bash\nexit 1\n' > "${WORKDIR}/bin/gum"
    run bash "${BLING_SCRIPT}"
    # Script exits non-zero (set -e + gum returning 1)
    [ "${status}" -ne 0 ]
    [ ! -f "${HOME}/.bashrc" ]
}

@test "ublue-bling: declining install in zsh does not modify .zshrc" {
    export SHELL="/bin/zsh"
    export ZDOTDIR="${HOME}"
    printf '#!/bin/bash\nexit 1\n' > "${WORKDIR}/bin/gum"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -ne 0 ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "ublue-bling: declining install in fish does not modify config.fish" {
    export SHELL="/bin/fish"
    mkdir -p "${HOME}/.config/fish"
    printf '#!/bin/bash\nexit 1\n' > "${WORKDIR}/bin/gum"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -ne 0 ]
    [ ! -f "${HOME}/.config/fish/config.fish" ]
}

@test "ublue-bling: declining uninstall leaves existing config intact" {
    export SHELL="/bin/bash"
    # Install first
    bash "${BLING_SCRIPT}"
    grep -qF "### bling.sh source start" "${HOME}/.bashrc"

    # Mock gum to decline uninstall prompt
    printf '#!/bin/bash\nexit 1\n' > "${WORKDIR}/bin/gum"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -ne 0 ]
    grep -qF "### bling.sh source start" "${HOME}/.bashrc"
}

# ---------------------------------------------------------------------------
# Unknown shell
# ---------------------------------------------------------------------------

@test "ublue-bling: exits non-zero for unsupported shell" {
    export SHELL="/bin/unknownshell_xyz"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -ne 0 ]
}

# ---------------------------------------------------------------------------
# is-bling-installed produces no debug output
# ---------------------------------------------------------------------------

@test "ublue-bling: is-bling-installed produces no stray stdout" {
    export SHELL="/bin/bash"
    run bash "${BLING_SCRIPT}"
    # Should not contain the debug 'hello' leak
    [[ "${output}" != *"hello"* ]]
}

# ---------------------------------------------------------------------------
# No shell trace output (`ujust bluefin-cli` must stay quiet, see #1672)
# ---------------------------------------------------------------------------

@test "ublue-bling: does not print shell trace output" {
    export SHELL="/bin/bash"
    # Set the trace prefix for the child shell only, so PS4 does not leak
    run env PS4='+TRACE: ' bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"+TRACE: "* ]]
}

# ---------------------------------------------------------------------------
# bluefin-cli installed: it replaces bling (#1719)
# ---------------------------------------------------------------------------

mock_bluefin_cli() {
    export BLUEFIN_CLI_CALLS="${WORKDIR}/bluefin-cli.calls"
    printf '#!/bin/bash\necho "bluefin-cli $*" >> "${BLUEFIN_CLI_CALLS}"\n' > "${WORKDIR}/bin/bluefin-cli"
    chmod +x "${WORKDIR}/bin/bluefin-cli"
}

@test "ublue-bling: with bluefin-cli, enabling turns on bluefin-cli instead of writing bling's block" {
    mock_bluefin_cli
    export SHELL="/bin/bash"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(cat "${BLUEFIN_CLI_CALLS}")" = "bluefin-cli shell bash on" ]
    [ ! -f "${HOME}/.bashrc" ]
}

@test "ublue-bling: with bluefin-cli, its rc line counts as enabled and is turned off" {
    mock_bluefin_cli
    export SHELL="/bin/zsh"
    unset ZDOTDIR
    echo 'eval "$(bluefin-cli init zsh)" # bluefin-cli shell-config' > "${HOME}/.zshrc"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(cat "${BLUEFIN_CLI_CALLS}")" = "bluefin-cli shell zsh off" ]
}

@test "ublue-bling: with bluefin-cli, an old bling block is removed and the shell turned off" {
    mock_bluefin_cli
    export SHELL="/bin/fish"
    mkdir -p "${HOME}/.config/fish"
    printf '### bling.fish source start\ntest -f %s/bling.fish && source %s/bling.fish\n### bling.fish source end\n' \
        "${BLING_CLI_DIRECTORY}" "${BLING_CLI_DIRECTORY}" > "${HOME}/.config/fish/config.fish"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -qF "bling.fish" "${HOME}/.config/fish/config.fish"
    [ "$(cat "${BLUEFIN_CLI_CALLS}")" = "bluefin-cli shell fish off" ]
}

@test "ublue-bling: with bluefin-cli, declining makes no bluefin-cli call" {
    mock_bluefin_cli
    export SHELL="/bin/bash"
    printf '#!/bin/bash\nexit 1\n' > "${WORKDIR}/bin/gum"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -ne 0 ]
    [ ! -f "${BLUEFIN_CLI_CALLS}" ]
}

@test "ublue-bling: without bluefin-cli, its rc line alone is not treated as bling" {
    export SHELL="/bin/bash"
    echo 'eval "$(bluefin-cli init bash)" # bluefin-cli shell-config' > "${HOME}/.bashrc"
    run bash "${BLING_SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qF "### bling.sh source start" "${HOME}/.bashrc"
}
