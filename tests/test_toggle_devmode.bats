#!/usr/bin/env bats
# Stub scripts and extracted recipes must expand variables only when executed.
# Per-test exports of mock switches are meant to stay inside that test.
# shellcheck disable=SC2016,SC2030,SC2031
# Tests for the toggle-devmode recipe in system.just.
#
# The recipe body is extracted into a standalone bash script and run against
# mocked gum/brew/flatpak/pkexec/just, so the selection-to-install mapping,
# the group membership hand-off and the marker file can be checked without
# installing packages or touching /etc/group. tests/test_native_recipes.bats
# covers the "decline at Install now?" path; this suite covers the rest.

bats_require_minimum_version 1.5.0

SYSTEM_JUST="${BATS_TEST_DIRNAME}/../system_files/bluefin/usr/share/ublue-os/just/system.just"

_extract_recipe() {
    local recipe="$1" out_file="$2"
    awk -v recipe="${recipe}" '
        $0 ~ ("^" recipe "([[:space:]].*)?:$") { found=1; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^    /, ""); print }
    ' "${SYSTEM_JUST}" | sed 's|{{ justfile() }}|${SYSTEM_JUST}|g' > "${out_file}"
    # Guard against a recipe rename silently producing an empty test subject.
    [ -s "${out_file}" ]
}

_write_mock() {
    local name="$1"
    cat > "${WORKDIR}/bin/${name}"
    chmod +x "${WORKDIR}/bin/${name}"
}

# _choose ITEM... — the items gum choose prints, one per line, exactly as the
# recipe offers them (including their two-space indent).
_choose() {
    printf '%s\n' "$@" > "${WORKDIR}/choices"
}

_run_devmode() {
    run env SYSTEM_JUST="${SYSTEM_JUST}" bash "${WORKDIR}/toggle-devmode.sh"
}

# Package and privilege calls only, in the order they were made.
_installs() {
    grep -E '^(brew|flatpak|pkexec|just) ' "${COMMAND_LOG}" || true
}

setup() {
    WORKDIR="$(mktemp -d)"
    export WORKDIR
    export HOME="${WORKDIR}/home"
    mkdir -p "${WORKDIR}/bin" "${HOME}"
    export COMMAND_LOG="${WORKDIR}/commands.log"
    : > "${COMMAND_LOG}"
    : > "${WORKDIR}/choices"
    export MOCK_CONFIRM_INSTALL=0 MOCK_CONFIRM_MORE=0

    _extract_recipe toggle-devmode "${WORKDIR}/toggle-devmode.sh"

    # gum: confirm answers per prompt, choose replays ${WORKDIR}/choices,
    # spin runs the wrapped command so its exit status reaches the recipe.
    _write_mock gum <<'MOCK'
#!/bin/bash
case "$1" in
    confirm)
        echo "gum confirm $2" >> "${COMMAND_LOG}"
        case "$2" in
            *"already set up"*) exit "${MOCK_CONFIRM_MORE}" ;;
            *) exit "${MOCK_CONFIRM_INSTALL}" ;;
        esac
        ;;
    choose)
        echo "gum choose" >> "${COMMAND_LOG}"
        cat "${WORKDIR}/choices"
        ;;
    spin)
        while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
            [ "$1" = "--title" ] && echo "gum spin title:$2" >> "${COMMAND_LOG}"
            shift
        done
        shift
        exec "$@"
        ;;
    style)
        shift
        printf '%s\n' "${@: -1}"
        ;;
esac
MOCK

    # brew fails for the package named in MOCK_BREW_FAIL.
    _write_mock brew <<'MOCK'
#!/bin/bash
echo "brew $*" >> "${COMMAND_LOG}"
if [ -n "${MOCK_BREW_FAIL:-}" ] && [[ " $* " == *" ${MOCK_BREW_FAIL} "* ]]; then
    exit 1
fi
MOCK

    _write_mock flatpak <<'MOCK'
#!/bin/bash
echo "flatpak $*" >> "${COMMAND_LOG}"
MOCK

    # pkexec records the privileged script instead of running it: the script
    # edits /etc/group and calls usermod.
    _write_mock pkexec <<'MOCK'
#!/bin/bash
echo "pkexec $1 $2" >> "${COMMAND_LOG}"
printf '%s' "$3" > "${WORKDIR}/pkexec-script"
MOCK

    _write_mock just <<'MOCK'
#!/bin/bash
echo "just $*" >> "${COMMAND_LOG}"
MOCK

    _write_mock id <<'MOCK'
#!/bin/bash
echo "devuser"
MOCK

    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "toggle-devmode: default Docker + Podman Desktop selection installs both and adds the docker group" {
    _choose "  Docker" "  Podman Desktop"
    _run_devmode
    [ "${status}" -eq 0 ]
    [ "$(_installs)" = "brew install devcontainer
brew install docker docker-compose lazydocker dive
flatpak install --system --noninteractive flathub io.podman_desktop.PodmanDesktop
pkexec bash -c" ]
    grep -q 'for g in dialout docker; do' "${WORKDIR}/pkexec-script"
    grep -q 'usermod -aG "${g}" devuser' "${WORKDIR}/pkexec-script"
    [ -f "${HOME}/.config/bluefin/devmode" ]
    [[ "${output}" == *"Developer Mode is on!"* ]]
}

@test "toggle-devmode: without Docker only the dialout group is added" {
    _choose "  Podman Desktop"
    _run_devmode
    [ "${status}" -eq 0 ]
    grep -q 'for g in dialout; do' "${WORKDIR}/pkexec-script"
    run ! grep -q 'docker' "${WORKDIR}/pkexec-script"
    run ! grep -q '^brew install docker' "${COMMAND_LOG}"
}

@test "toggle-devmode: every option maps to its own install command, in menu order" {
    _choose "  Docker" "  Podman Desktop" \
        "  Lima (lightweight Linux VM, WSL/container machine equivalent)" \
        "  VS Code" "  VSCodium" "  Antigravity" "  Zed" "  JetBrains Toolbox" \
        "  Neovim" "  Helix" "  vim" "  micro"
    _run_devmode
    [ "${status}" -eq 0 ]
    [ "$(_installs)" = "brew tap ublue-os/tap
brew trust ublue-os/tap
brew install devcontainer
brew install docker docker-compose lazydocker dive
flatpak install --system --noninteractive flathub io.podman_desktop.PodmanDesktop
brew install lima
brew install --cask ublue-os/tap/visual-studio-code-linux
brew install --cask ublue-os/tap/vscodium-linux
brew install --cask ublue-os/tap/antigravity-linux
brew install --cask ublue-os/tap/zed-linux
brew install --cask ublue-os/tap/jetbrains-toolbox-linux
brew install nvim
brew install helix
brew install vim
brew install micro
pkexec bash -c
just --justfile ${SYSTEM_JUST} setup-lima" ]
}

@test "toggle-devmode: progress titles count every queued install" {
    _choose "  Docker" "  Helix"
    _run_devmode
    [ "${status}" -eq 0 ]
    # 28-cell bar, filled = done * 28 / total: 0, 9 and 18 cells for 3 steps.
    local empty28="░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
    local bar1="█████████░░░░░░░░░░░░░░░░░░░"
    local bar2="██████████████████░░░░░░░░░░"
    [ "$(grep '^gum spin title:' "${COMMAND_LOG}")" = "gum spin title: ${empty28}  1/3  devcontainer CLI
gum spin title: ${bar1}  2/3  Docker
gum spin title: ${bar2}  3/3  Helix" ]
    [[ "${output}" == *"✓ Helix"* ]]
}

@test "toggle-devmode: Neovim does not also install vim" {
    _choose "  Neovim"
    _run_devmode
    [ "${status}" -eq 0 ]
    grep -qx 'brew install nvim' "${COMMAND_LOG}"
    run ! grep -qx 'brew install vim' "${COMMAND_LOG}"
}

@test "toggle-devmode: vim does not also install Neovim" {
    _choose "  vim"
    _run_devmode
    [ "${status}" -eq 0 ]
    grep -qx 'brew install vim' "${COMMAND_LOG}"
    run ! grep -qx 'brew install nvim' "${COMMAND_LOG}"
}

@test "toggle-devmode: VS Code and VSCodium are selected independently" {
    _choose "  VSCodium"
    _run_devmode
    [ "${status}" -eq 0 ]
    grep -qx 'brew install --cask ublue-os/tap/vscodium-linux' "${COMMAND_LOG}"
    run ! grep -q 'visual-studio-code-linux' "${COMMAND_LOG}"

    : > "${COMMAND_LOG}"
    _choose "  VS Code"
    _run_devmode
    [ "${status}" -eq 0 ]
    grep -qx 'brew install --cask ublue-os/tap/visual-studio-code-linux' "${COMMAND_LOG}"
    run ! grep -q 'vscodium-linux' "${COMMAND_LOG}"
}

@test "toggle-devmode: the ublue-os tap is only added for GUI editors" {
    _choose "  Docker" "  Neovim" "  Helix" "  vim" "  micro"
    _run_devmode
    [ "${status}" -eq 0 ]
    run ! grep -q '^brew tap\|^brew trust' "${COMMAND_LOG}"
}

@test "toggle-devmode: a selected section header installs nothing beyond the devcontainer CLI" {
    _choose "── Docker ───────────────────────────────────" \
        "── Virtualization ───────────────────────────" \
        "── IDE ──────────────────────────────────────" \
        "── CLI Editors ──────────────────────────────"
    _run_devmode
    [ "${status}" -eq 0 ]
    [ "$(_installs)" = "brew install devcontainer
pkexec bash -c" ]
    grep -q 'for g in dialout; do' "${WORKDIR}/pkexec-script"
}

@test "toggle-devmode: an empty selection still installs the devcontainer CLI" {
    _run_devmode
    [ "${status}" -eq 0 ]
    [ "$(_installs)" = "brew install devcontainer
pkexec bash -c" ]
    [ -f "${HOME}/.config/bluefin/devmode" ]
}

@test "toggle-devmode: without Lima, setup-lima is not run" {
    _choose "  Docker"
    _run_devmode
    [ "${status}" -eq 0 ]
    run ! grep -q '^just ' "${COMMAND_LOG}"
}

@test "toggle-devmode: an install failure stops the queue before groups and marker" {
    export MOCK_BREW_FAIL=docker
    _choose "  Docker" "  Podman Desktop" "  Neovim"
    _run_devmode
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"✗ Docker"* ]]
    grep -qx 'brew install devcontainer' "${COMMAND_LOG}"
    run ! grep -q '^flatpak ' "${COMMAND_LOG}"
    run ! grep -qx 'brew install nvim' "${COMMAND_LOG}"
    run ! grep -q '^pkexec ' "${COMMAND_LOG}"
    [ ! -e "${HOME}/.config/bluefin/devmode" ]
}

@test "toggle-devmode: Lima install failure skips setup-lima" {
    export MOCK_BREW_FAIL=lima
    _choose "  Lima (lightweight Linux VM, WSL/container machine equivalent)"
    _run_devmode
    [ "${status}" -eq 1 ]
    run ! grep -q '^just ' "${COMMAND_LOG}"
}

@test "toggle-devmode: first run does not ask whether to add more tools" {
    _choose "  Docker"
    _run_devmode
    [ "${status}" -eq 0 ]
    run ! grep -q 'already set up' "${COMMAND_LOG}"
}

@test "toggle-devmode: when already set up, declining 'add more' exits before the menu" {
    mkdir -p "${HOME}/.config/bluefin"
    touch "${HOME}/.config/bluefin/devmode"
    export MOCK_CONFIRM_MORE=1
    _choose "  Docker"
    _run_devmode
    [ "${status}" -eq 0 ]
    grep -q '^gum confirm Developer mode is already set up. Add more tools?$' "${COMMAND_LOG}"
    run ! grep -q '^gum choose' "${COMMAND_LOG}"
    [ -z "$(_installs)" ]
}

@test "toggle-devmode: when already set up, accepting 'add more' installs the new selection" {
    mkdir -p "${HOME}/.config/bluefin"
    touch "${HOME}/.config/bluefin/devmode"
    _choose "  Zed"
    _run_devmode
    [ "${status}" -eq 0 ]
    grep -qx 'brew install --cask ublue-os/tap/zed-linux' "${COMMAND_LOG}"
    [ -f "${HOME}/.config/bluefin/devmode" ]
}
