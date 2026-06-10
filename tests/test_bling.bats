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

    # Isolated home directory
    export HOME="${WORKDIR}/home"
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
    export XDG_CONFIG_HOME="${HOME}/.config"
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
