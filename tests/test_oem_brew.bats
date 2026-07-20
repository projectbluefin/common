#!/usr/bin/env bats
# Tests for system_files/shared/usr/share/ublue-os/user-setup.hooks.d/20-oem-brew.sh
#
# The hook reads DMI vendor data, selects an OEM payload, and applies the
# selected Brewfile and post-install actions. Tests patch only its hardcoded
# system paths; production behavior is unchanged.
#
# Run: bats tests/test_oem_brew.bats

OEM_BREW_HOOK="$BATS_TEST_DIRNAME/../system_files/shared/usr/share/ublue-os/user-setup.hooks.d/20-oem-brew.sh"
LIBSETUP_REAL="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/ublue/setup-services/libsetup.sh"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    export WORKDIR
    export HOME="${WORKDIR}/home"
    mkdir -p "${HOME}/.local/share/ublue" "${WORKDIR}/sys/devices/virtual/dmi/id"

    # Default to an unrelated machine. Individual tests set the vendor they
    # need, so a positive test cannot pass by inheriting setup state.
    printf '%s\n' "Generic" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    printf '%s\n' "Generic" > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    printf '%s\n' "Generic PC" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"

    mkdir -p "${WORKDIR}/bin"

    # The hook calls the absolute BREW_BIN for shellenv, then calls brew from
    # PATH for bundle. Log every invocation so assertions cover full args.
    cat > "${WORKDIR}/bin/brew" << 'BREW_MOCK'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >> "${WORKDIR}/brew.log"
if [[ "$1" == "shellenv" ]]; then
    printf '# brew shellenv mock\n'
fi
BREW_MOCK
    chmod +x "${WORKDIR}/bin/brew"

    cat > "${WORKDIR}/bin/systemctl" << 'SYSTEMCTL_MOCK'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "${WORKDIR}/systemctl.log"
SYSTEMCTL_MOCK
    chmod +x "${WORKDIR}/bin/systemctl"

    cat > "${WORKDIR}/bin/dconf" << 'DCONF_MOCK'
#!/usr/bin/env bash
printf 'dconf %s\n' "$*" >> "${WORKDIR}/dconf.log"
DCONF_MOCK
    chmod +x "${WORKDIR}/bin/dconf"

    export PATH="${WORKDIR}/bin:${PATH}"

    mkdir -p "${WORKDIR}/oem/Framework" "${WORKDIR}/oem/ASUS"
    printf '%s\n' '# Framework Brewfile' > "${WORKDIR}/oem/Framework/packages.Brewfile"
    printf '%s\n' '# ASUS Brewfile' > "${WORKDIR}/oem/ASUS/packages.Brewfile"
}

teardown() {
    rm -rf "${WORKDIR}"
}

_patched_script() {
    local patched_script="${WORKDIR}/oem-brew-patched.sh"
    sed \
        -e "s|source /usr/lib/ublue/setup-services/libsetup.sh|source ${LIBSETUP_REAL}|" \
        -e "s|BREW_BIN=\"/var/home/linuxbrew/.linuxbrew/bin/brew\"|BREW_BIN=\"${WORKDIR}/bin/brew\"|" \
        -e "s|OEM_DIR=\"/usr/share/ublue-os/oem\"|OEM_DIR=\"${WORKDIR}/oem\"|" \
        -e "s|/sys/devices/virtual/dmi/id/chassis_vendor|${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor|g" \
        -e "s|/sys/devices/virtual/dmi/id/sys_vendor|${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor|g" \
        -e "s|/sys/devices/virtual/dmi/id/product_name|${WORKDIR}/sys/devices/virtual/dmi/id/product_name|g" \
        "${OEM_BREW_HOOK}" > "${patched_script}"
    chmod +x "${patched_script}"
    printf '%s\n' "${patched_script}"
}

_assert_brew_bundle() {
    local vendor="$1"
    local expected="brew bundle --file=${WORKDIR}/oem/${vendor}/packages.Brewfile"
    grep -Fx -- "${expected}" "${WORKDIR}/brew.log"
}

@test "oem-brew: unknown vendor exits without invoking any OEM command" {
    printf '%s\n' "Dell Inc." > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    printf '%s\n' "Dell Inc." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [ ! -e "${WORKDIR}/brew.log" ]
    [ ! -e "${WORKDIR}/systemctl.log" ]
    [ ! -e "${WORKDIR}/dconf.log" ]
}

@test "oem-brew: Framework chassis vendor selects Framework Brewfile" {
    printf '%s\n' "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    _assert_brew_bundle Framework
}

@test "oem-brew: ASUS sys vendor selects ASUS Brewfile for ASUSTeK" {
    printf '%s\n' "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    _assert_brew_bundle ASUS
}

@test "oem-brew: ASUS sys vendor accepts the short ASUS form" {
    printf '%s\n' "ASUS Computer Inc." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    _assert_brew_bundle ASUS
}

@test "oem-brew: vendor text in sys_vendor does not spoof Framework detection" {
    printf '%s\n' "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [ ! -e "${WORKDIR}/brew.log" ]
}

@test "oem-brew: vendor text in chassis_vendor does not spoof ASUS detection" {
    printf '%s\n' "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [ ! -e "${WORKDIR}/brew.log" ]
}

@test "oem-brew: missing brew exits cleanly and requests a retry" {
    printf '%s\n' "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    rm "${WORKDIR}/bin/brew"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"oem-brew: brew not found, will retry on next login"* ]]
}

@test "oem-brew: ASUS enables asusd-user.service with exact arguments" {
    printf '%s\n' "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    grep -Fx -- 'systemctl --user daemon-reload' "${WORKDIR}/systemctl.log"
    grep -Fx -- 'systemctl --user enable --now asusd-user.service' "${WORKDIR}/systemctl.log"
}

@test "oem-brew: Framework does not enable the ASUS user service" {
    printf '%s\n' "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [ ! -e "${WORKDIR}/systemctl.log" ]
}

@test "oem-brew: logo writes the exact dconf command arguments" {
    printf '%s\n' "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    printf '%s\n' "asus-rog-symbolic" > "${WORKDIR}/oem/ASUS/logo"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    grep -Fx -- "dconf write /org/gnome/shell/extensions/custom-command-list/menuicon-setting 'asus-rog-symbolic'" \
        "${WORKDIR}/dconf.log"
}

@test "oem-brew: Framework Desktop installs its exact WirePlumber payload" {
    printf '%s\n' "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    printf '%s\n' "Framework Desktop" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"
    printf '%s\n' '# wireplumber config' > "${WORKDIR}/oem/Framework/51-framework-desktop.conf"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    local wp_conf="${HOME}/.config/wireplumber/wireplumber.conf.d/51-framework-desktop.conf"
    [ -f "${wp_conf}" ]
    cmp -s "${WORKDIR}/oem/Framework/51-framework-desktop.conf" "${wp_conf}"
}

@test "oem-brew: non-Desktop Framework skips the WirePlumber payload" {
    printf '%s\n' "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    printf '%s\n' "Laptop 13 (AMD Ryzen)" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"
    printf '%s\n' '# wireplumber config' > "${WORKDIR}/oem/Framework/51-framework-desktop.conf"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.config/wireplumber/wireplumber.conf.d/51-framework-desktop.conf" ]
}

@test "oem-brew: missing OEM directory exits without invoking brew" {
    printf '%s\n' "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    rm -rf "${WORKDIR}/oem/Framework"

    run bash "$(_patched_script)"
    [ "${status}" -eq 0 ]
    [ ! -e "${WORKDIR}/brew.log" ]
}
