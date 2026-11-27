#!/usr/bin/env bats
# Stub scripts and extracted recipes must expand variables only when executed.
# shellcheck disable=SC2016
# Exercise native recipes with a leftover bctl installed. All system-changing
# commands are mocked; never switch images, install packages, or reset the host.

bats_require_minimum_version 1.5.0

# Match the extraction approach used by the update/changelog suites so CI
# needs only bash and bats, not a particular version of the just parser.
_extract_recipe() {
    local file="$1" recipe="$2"
    awk -v recipe="${recipe}" '
        $0 ~ ("^" recipe "([[:space:]].*)?:$") { found=1; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^    /, ""); print }
    ' "${file}" | sed 's/{{ justfile() }}/${SYSTEM_JUST}/g'
}

_run_recipe() {
    local file="$1" recipe="$2"
    _extract_recipe "${file}" "${recipe}" > "${WORKDIR}/${recipe}.sh"
    run env confirm="${3:-1}" bash "${WORKDIR}/${recipe}.sh"
}

setup() {
    WORKDIR="$(mktemp -d)"
    export WORKDIR
    export HOME="${WORKDIR}/home" XDG_CONFIG_HOME="${WORKDIR}/home/.config"
    export SHELL=/bin/bash
    unset ZDOTDIR
    mkdir -p "${WORKDIR}/bin" "${HOME}"
    export COMMAND_LOG="${WORKDIR}/commands.log"
    touch "${COMMAND_LOG}"
    ROOT="${BATS_TEST_DIRNAME}/.."
    export SYSTEM_JUST="${WORKDIR}/system.just"
    SHARED_JUST="${ROOT}/system_files/shared/usr/share/ublue-os/just/shared.just"
    # Keep the absolute libvirt helper isolated without changing production code.
    sed "s|/usr/libexec/ensure-libvirt-session-config|${WORKDIR}/bin/ensure-libvirt-session-config|g" \
        "${ROOT}/system_files/bluefin/usr/share/ublue-os/just/system.just" > "${SYSTEM_JUST}"
    _extract_recipe "${SYSTEM_JUST}" setup-vms > "${WORKDIR}/setup-vms.sh"
    export IMAGE_INFO_FILE="${WORKDIR}/image-info.json"
    printf '{"image-tag":"stable","image-ref":"ostree-image-signed:docker://ghcr.io/projectbluefin/bluefin"}' > "${IMAGE_INFO_FILE}"

    for cmd in bootc brew ublue-bling ujust ensure-libvirt-session-config limactl; do
        printf '#!/bin/bash\necho "%s $*" >> "${COMMAND_LOG}"\n' "${cmd}" > "${WORKDIR}/bin/${cmd}"
    done
    for cmd in sudo pkexec; do
        printf '#!/bin/bash\necho "%s $*" >> "${COMMAND_LOG}"\nexec "$@"\n' "${cmd}" > "${WORKDIR}/bin/${cmd}"
    done
    cat > "${WORKDIR}/bin/just" <<'MOCK'
#!/bin/bash
if [[ "$1" == "--justfile" && "$2" == "${SYSTEM_JUST}" ]]; then
    if [[ "$3" == "setup-vms" ]]; then
        exec bash "${WORKDIR}/setup-vms.sh"
    fi
fi
exit 99
MOCK
    cat > "${WORKDIR}/bin/bctl" <<'MOCK'
#!/bin/bash
echo "unexpected bctl invocation" >> "${COMMAND_LOG}"
exit 99
MOCK
    cat > "${WORKDIR}/bin/flatpak" <<'MOCK'
#!/bin/bash
echo "flatpak $*" >> "${COMMAND_LOG}"
if [[ "$1" == "list" ]]; then
    printf '%s\n' "${MOCK_FLATPAK_LIST:-}"
fi
MOCK
    # skopeo stays silent so the absent-target guard cannot prove a tag is
    # missing and stays inert; this also keeps the suite off the network when a
    # real skopeo is installed on the host.
    cat > "${WORKDIR}/bin/skopeo" <<'MOCK'
#!/bin/bash
echo "skopeo $*" >> "${COMMAND_LOG}"
exit 0
MOCK
    cat > "${WORKDIR}/bin/gum" <<'MOCK'
#!/bin/bash
echo "gum $*" >> "${COMMAND_LOG}"
case "$1" in
    confirm) exit "${MOCK_CONFIRM_STATUS:-1}" ;;
    choose)
        if [[ -f "${WORKDIR}/chosen-once" ]]; then
            printf '%s\n' "${MOCK_SECOND_CHOICE:-No}"
        else
            touch "${WORKDIR}/chosen-once"
            printf '%s\n' "${MOCK_FIRST_CHOICE:-No}"
        fi
        ;;
esac
MOCK
    chmod +x "${WORKDIR}/bin/"*
    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "native recipes: shipped files contain no bluefinctl provisioning or handoffs" {
    # The on-device agent bundle (system_files/.../agent/) is documentation and
    # may name bctl/bluefinctl while describing the policy against using it, so
    # exclude it from this provisioning/handoff scan. See AGENTS.md in that dir.
    run grep -rInE --exclude-dir=agent '\b(bctl|bluefinctl)\b' "${ROOT}/system_files"
    [ "${status}" -eq 1 ]
    [ ! -e "${ROOT}/system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/bluefinctl.Brewfile" ]
}

@test "native bluefin-cli: enabling installs CLI bundle" {
    _run_recipe "${SYSTEM_JUST}" bluefin-cli
    [ "${status}" -eq 0 ]
    grep -q '^ublue-bling ' "${COMMAND_LOG}"
    grep -q '^brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile$' "${COMMAND_LOG}"
}

@test "native bluefin-cli: disabling does not reinstall CLI bundle" {
    echo 'source /usr/share/ublue-os/bling/bling.sh' > "${HOME}/.bashrc"
    _run_recipe "${SYSTEM_JUST}" bluefin-cli
    [ "${status}" -eq 0 ]
    grep -q '^ublue-bling ' "${COMMAND_LOG}"
    run ! grep -q '^brew ' "${COMMAND_LOG}"
}

@test "native bluefin-cli: enabling in fish installs CLI bundle" {
    SHELL=/usr/bin/fish _run_recipe "${SYSTEM_JUST}" bluefin-cli
    [ "${status}" -eq 0 ]
    grep -q '^ublue-bling ' "${COMMAND_LOG}"
    grep -q '^brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile$' "${COMMAND_LOG}"
}

@test "native bluefin-cli: disabling in fish does not reinstall CLI bundle" {
    mkdir -p "${HOME}/.config/fish"
    echo 'source /usr/share/ublue-os/bling/bling.fish' > "${HOME}/.config/fish/config.fish"
    SHELL=/usr/bin/fish _run_recipe "${SYSTEM_JUST}" bluefin-cli
    [ "${status}" -eq 0 ]
    grep -q '^ublue-bling ' "${COMMAND_LOG}"
    run ! grep -q '^brew ' "${COMMAND_LOG}"
}

@test "native bluefin-cli: enabling in zsh installs CLI bundle" {
    SHELL=/usr/bin/zsh _run_recipe "${SYSTEM_JUST}" bluefin-cli
    [ "${status}" -eq 0 ]
    grep -q '^ublue-bling ' "${COMMAND_LOG}"
    grep -q '^brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile$' "${COMMAND_LOG}"
}

@test "native bluefin-cli: disabling in zsh does not reinstall CLI bundle" {
    echo 'source /usr/share/ublue-os/bling/bling.sh' > "${HOME}/.zshrc"
    SHELL=/usr/bin/zsh _run_recipe "${SYSTEM_JUST}" bluefin-cli
    [ "${status}" -eq 0 ]
    grep -q '^ublue-bling ' "${COMMAND_LOG}"
    run ! grep -q '^brew ' "${COMMAND_LOG}"
}

@test "native bluefin-cli: unknown shell aborts with error" {
    SHELL=/bin/unknownshell _run_recipe "${SYSTEM_JUST}" bluefin-cli
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Unknown shell: unknownshell"* ]]
    run ! grep -q '^ublue-bling ' "${COMMAND_LOG}"
    run ! grep -q '^brew ' "${COMMAND_LOG}"
}

@test "native bluefin-cli: ublue-bling failure aborts before brew bundle" {
    cat > "${WORKDIR}/bin/ublue-bling" <<'FAILMOCK'
#!/bin/bash
echo "ublue-bling failed" >> "${COMMAND_LOG}"
exit 1
FAILMOCK
    chmod +x "${WORKDIR}/bin/ublue-bling"
    _run_recipe "${SYSTEM_JUST}" bluefin-cli
    [ "${status}" -ne 0 ]
    grep -q '^ublue-bling failed' "${COMMAND_LOG}"
    run ! grep -q '^brew ' "${COMMAND_LOG}"
}

@test "native bluefin-cli: brew bundle failure propagates non-zero exit" {
    cat > "${WORKDIR}/bin/brew" <<'FAILBREW'
#!/bin/bash
echo "brew $*" >> "${COMMAND_LOG}"
exit 1
FAILBREW
    chmod +x "${WORKDIR}/bin/brew"
    _run_recipe "${SYSTEM_JUST}" bluefin-cli
    [ "${status}" -ne 0 ]
    grep -q '^brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile$' "${COMMAND_LOG}"
}


@test "native setup-vms: installs both flatpaks and runs the libvirt helper" {
    _run_recipe "${SYSTEM_JUST}" setup-vms
    [ "${status}" -eq 0 ]
    grep -qFx 'flatpak install --system --noninteractive flathub org.virt_manager.virt-manager org.virt_manager.virt_manager.Extension.Qemu' "${COMMAND_LOG}"
    grep -q '^ensure-libvirt-session-config ' "${COMMAND_LOG}"
}

@test "native toggle-vms: confirmation installs the native VM stack" {
    MOCK_CONFIRM_STATUS=0 _run_recipe "${SYSTEM_JUST}" toggle-vms
    [ "${status}" -eq 0 ]
    grep -q '^flatpak install ' "${COMMAND_LOG}"
    grep -q '^ensure-libvirt-session-config ' "${COMMAND_LOG}"
}

@test "native toggle-vms: declining removal leaves the VM stack alone" {
    MOCK_FLATPAK_LIST=org.virt_manager.virt-manager _run_recipe "${SYSTEM_JUST}" toggle-vms
    [ "${status}" -eq 0 ]
    grep -q '^gum confirm Remove the VM stack' "${COMMAND_LOG}"
    run ! grep -q '^flatpak uninstall ' "${COMMAND_LOG}"
}
