#!/usr/bin/env bats
# Tests for system_files/shared/usr/share/ublue-os/user-setup.hooks.d/10-theming.sh
#
# Run: bats tests/test_theming_hook.bats

THEMING_HOOK="$BATS_TEST_DIRNAME/../system_files/shared/usr/share/ublue-os/user-setup.hooks.d/10-theming.sh"
LIBSETUP_REAL="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/ublue/setup-services/libsetup.sh"

WORKDIR=""
PATCHED_HOOK=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/sys/devices/virtual/dmi/id" "${WORKDIR}/bin"

    # Default hardware: no special theming path.
    echo "Generic Vendor" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Generic Product" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"

    # Patch absolute source/sys paths so hook runs in temp dir.
    PATCHED_HOOK="${WORKDIR}/10-theming.sh"
    sed \
        -e "s|source /usr/lib/ublue/setup-services/libsetup.sh|source ${LIBSETUP_REAL}|g" \
        -e "s|/sys/devices/virtual/dmi/id|${WORKDIR}/sys/devices/virtual/dmi/id|g" \
        "${THEMING_HOOK}" > "${PATCHED_HOOK}"
    chmod +x "${PATCHED_HOOK}"

    # Record dconf writes instead of touching host settings.
    cat > "${WORKDIR}/bin/dconf" << MOCK
#!/bin/bash
echo "\$*" >> "${WORKDIR}/dconf.log"
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/dconf"

    export PATH="${WORKDIR}/bin:${PATH}"
    export SETUP_CHECKER_FILE="${WORKDIR}/setup_versioning.json"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "10-theming: no-op on non-matching hardware" {
    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    [ ! -s "${WORKDIR}/dconf.log" ]
}

@test "10-theming: Framework sets natural-scroll" {
    echo "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Desktop 99" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    grep -q "/org/gnome/desktop/peripherals/mouse/natural-scroll true" "${WORKDIR}/dconf.log"
    ! grep -q "/org/gnome/desktop/interface/text-scaling-factor" "${WORKDIR}/dconf.log"
}

@test "10-theming: Framework Laptop 13 applies text scaling fix" {
    echo "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Laptop (13 Intel Core Ultra)" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    grep -q "/org/gnome/desktop/peripherals/mouse/natural-scroll true" "${WORKDIR}/dconf.log"
    grep -q "/org/gnome/desktop/interface/text-scaling-factor 1.25" "${WORKDIR}/dconf.log"
}

@test "10-theming: Thelio Astra sets Ampere menu icon" {
    echo "System76" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Thelio Astra" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]
    grep -q "/org/gnome/shell/extensions/custom-command-list/menuicon-setting 'ampere-logo-symbolic'" "${WORKDIR}/dconf.log"
}

@test "10-theming: version-script gate prevents second run side effects" {
    echo "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Laptop (13 AMD Ryzen)" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    run bash "${PATCHED_HOOK}"
    [ "${status}" -eq 0 ]

    [ "$(wc -l < "${WORKDIR}/dconf.log")" -eq 2 ]
}
