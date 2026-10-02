#!/usr/bin/env bats
# Tests for system-setup hooks: 10-framework.sh and 11-asus.sh
#
# Both scripts support:
#   LIBSETUP — path to libsetup.sh (defaults to /usr/lib/ublue/setup-services/libsetup.sh)
#   SYSROOT  — prefix for /sys, /proc, /etc reads (defaults to empty = real paths)
#
# Run: bats tests/test_hardware_hooks.bats

FRAMEWORK_HOOK="$BATS_TEST_DIRNAME/../system_files/shared/usr/share/ublue-os/system-setup.hooks.d/10-framework.sh"
ASUS_HOOK="$BATS_TEST_DIRNAME/../system_files/shared/usr/share/ublue-os/system-setup.hooks.d/11-asus.sh"
LIBSETUP_REAL="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/ublue/setup-services/libsetup.sh"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"

    # Fake DMI/proc filesystem
    mkdir -p \
        "${WORKDIR}/sys/devices/virtual/dmi/id" \
        "${WORKDIR}/proc" \
        "${WORKDIR}/etc/modprobe.d" \
        "${WORKDIR}/etc/udev/rules.d" \
        "${WORKDIR}/etc"

    # Default: non-Framework, non-ASUS, AMD CPU
    echo "AuthenticAMD" > "${WORKDIR}/proc/cpuinfo_vendor"
    printf 'vendor_id\t: AuthenticAMD\n' > "${WORKDIR}/proc/cpuinfo"
    echo "Generic" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Generic Desktop" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"
    echo "1.00" > "${WORKDIR}/sys/devices/virtual/dmi/id/bios_version"
    echo "Generic Vendor" > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    echo "ID=fedora" > "${WORKDIR}/etc/os-release"

    # Mock commands that must not run for real in tests
    mkdir -p "${WORKDIR}/bin"
    for cmd in reboot plymouth udevadm; do
        printf '#!/bin/bash\necho "mock: %s $*" >&2\nexit 0\n' "$cmd" \
            > "${WORKDIR}/bin/$cmd"
        chmod +x "${WORKDIR}/bin/$cmd"
    done
    # systemctl: list-unit-files must output something for 11-asus.sh
    cat > "${WORKDIR}/bin/systemctl" << 'EOF'
#!/bin/bash
case "$*" in
    "list-unit-files asusd.service")
        echo "asusd.service enabled"
        exit 0
        ;;
    "list-unit-files asus-shutdown.service")
        echo "asus-shutdown.service enabled"
        exit 0
        ;;
    "enable --now asusd.service")
        echo "mock: systemctl enable asusd.service" >&2
        exit 0
        ;;
    "enable --now asus-shutdown.service")
        echo "mock: systemctl enable asus-shutdown.service" >&2
        exit 0
        ;;
    *)
        echo "mock: systemctl $*" >&2
        exit 0
        ;;
esac
EOF
    chmod +x "${WORKDIR}/bin/systemctl"

    export PATH="${WORKDIR}/bin:${PATH}"
    export LIBSETUP="${LIBSETUP_REAL}"
    export SYSROOT="${WORKDIR}"
    export SETUP_CHECKER_FILE="${WORKDIR}/setup_versioning.json"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# 10-framework.sh — non-Framework hardware
# ---------------------------------------------------------------------------

@test "10-framework: exits cleanly on non-Framework hardware" {
    run bash "${FRAMEWORK_HOOK}"
    [ "${status}" -eq 0 ]
}

@test "10-framework: does not run karg cleanup on non-Framework hardware" {
    run bash "${FRAMEWORK_HOOK}"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Removing obsolete hid_sensor_hub karg"* ]]
}

# ---------------------------------------------------------------------------
# 10-framework.sh — Intel Framework (kargs fix)
# ---------------------------------------------------------------------------

@test "10-framework: detects Intel Framework and cleans up legacy rpm-ostree karg" {
    echo "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    printf 'vendor_id\t: GenuineIntel\n' > "${WORKDIR}/proc/cpuinfo"
    cat > "${WORKDIR}/bin/rpm-ostree" << 'EOF'
#!/bin/bash
case "$1" in
    kargs)
        if [[ "$*" == *"delete-if-present"* ]]; then
            echo "mock: rpm-ostree kargs delete" >&2
        else
            echo "quiet module_blacklist=hid_sensor_hub splash"
        fi
        ;;
esac
exit 0
EOF
    chmod +x "${WORKDIR}/bin/rpm-ostree"

    run bash "${FRAMEWORK_HOOK}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Removing obsolete hid_sensor_hub karg via rpm-ostree"* ]]
    [[ "${output}" == *"mock: rpm-ostree kargs delete"* ]]
}

# ---------------------------------------------------------------------------
# 10-framework.sh — Framework 13 AMD audio jack fix
# ---------------------------------------------------------------------------

@test "10-framework: applies alsa.conf on Framework 13 AMD non-Fedora kernel" {
    echo "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Laptop 13 (AMD Ryzen)" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"
    printf 'vendor_id\t: AuthenticAMD\n' > "${WORKDIR}/proc/cpuinfo"
    echo "ID=rhel" > "${WORKDIR}/etc/os-release"

    run bash "${FRAMEWORK_HOOK}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/etc/modprobe.d/alsa.conf" ]
    grep -q "snd-hda-intel" "${WORKDIR}/etc/modprobe.d/alsa.conf"
}

@test "10-framework: removes alsa.conf on Framework 13 AMD Fedora kernel" {
    echo "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Laptop 13 (AMD Ryzen)" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"
    printf 'vendor_id\t: AuthenticAMD\n' > "${WORKDIR}/proc/cpuinfo"
    echo "ID=fedora" > "${WORKDIR}/etc/os-release"
    echo "# old fix" > "${WORKDIR}/etc/modprobe.d/alsa.conf"

    run bash "${FRAMEWORK_HOOK}"
    [ "${status}" -eq 0 ]
    [ ! -f "${WORKDIR}/etc/modprobe.d/alsa.conf" ]
}

# ---------------------------------------------------------------------------
# 10-framework.sh — Framework 13 Ryzen 7040 suspend fix
# ---------------------------------------------------------------------------

@test "10-framework: applies suspend workaround on old BIOS" {
    echo "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Laptop 13 (AMD Ryzen 7040Series)" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"
    echo "03.05" > "${WORKDIR}/sys/devices/virtual/dmi/id/bios_version"
    printf 'vendor_id\t: AuthenticAMD\n' > "${WORKDIR}/proc/cpuinfo"

    run bash "${FRAMEWORK_HOOK}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/etc/udev/rules.d/20-suspend-fixes.rules" ]
}

@test "10-framework: removes suspend workaround on new BIOS" {
    echo "Framework" > "${WORKDIR}/sys/devices/virtual/dmi/id/chassis_vendor"
    echo "Laptop 13 (AMD Ryzen 7040Series)" > "${WORKDIR}/sys/devices/virtual/dmi/id/product_name"
    echo "03.09" > "${WORKDIR}/sys/devices/virtual/dmi/id/bios_version"
    printf 'vendor_id\t: AuthenticAMD\n' > "${WORKDIR}/proc/cpuinfo"
    echo "old rule" > "${WORKDIR}/etc/udev/rules.d/20-suspend-fixes.rules"

    run bash "${FRAMEWORK_HOOK}"
    [ "${status}" -eq 0 ]
    [ ! -f "${WORKDIR}/etc/udev/rules.d/20-suspend-fixes.rules" ]
}

# ---------------------------------------------------------------------------
# 11-asus.sh
# ---------------------------------------------------------------------------

@test "11-asus: exits cleanly on non-ASUS hardware" {
    echo "Dell Inc." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]
}

@test "11-asus: exits cleanly on non-ASUS hardware (generic)" {
    echo "LENOVO" > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]
}

@test "11-asus: detects ASUSTeK and enables asusd service" {
    echo "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"ASUS hardware detected"* ]]
    [[ "${output}" == *"mock: systemctl enable asusd.service"* ]]
    [[ "${output}" == *"mock: systemctl enable asus-shutdown.service"* ]]
}

@test "11-asus: detects ASUS (short form) and runs setup" {
    echo "ASUS" > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"ASUS"* ]]
}

@test "11-asus: reloads udev and skips the version commit when enable fails" {
    echo "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    # asusd failing to start is transient: udev must still be reloaded and the
    # version left unrecorded so the hook retries on the next boot.
    cat > "${WORKDIR}/bin/systemctl" << 'EOF'
#!/bin/bash
case "$*" in
    "list-unit-files asusd.service") echo "asusd.service enabled"; exit 0 ;;
    "enable --now asusd.service") exit 1 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "${WORKDIR}/bin/systemctl"

    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"mock: udevadm control --reload"* ]]
    [[ "${output}" == *"not recording the version"* ]]
    run jq -r '.version.system.asus' "${SETUP_CHECKER_FILE}"
    [ "${output}" != "1" ]
}

@test "11-asus: records the version when asus-shutdown.service is absent" {
    echo "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    # asus-shutdown.service is optional: a permanently missing unit must not
    # block the commit, otherwise the hook reloads udev on every boot forever.
    cat > "${WORKDIR}/bin/systemctl" << 'EOF'
#!/bin/bash
case "$*" in
    "list-unit-files asusd.service") echo "asusd.service enabled"; exit 0 ;;
    "list-unit-files asus-shutdown.service") exit 1 ;;
    "enable --now asus-shutdown.service") exit 1 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "${WORKDIR}/bin/systemctl"

    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"asus-shutdown.service not present"* ]]
    run jq -r '.version.system.asus' "${SETUP_CHECKER_FILE}"
    [ "${output}" = "1" ]
}

@test "11-asus: second boot does nothing when asus-shutdown.service stays absent" {
    echo "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    cat > "${WORKDIR}/bin/systemctl" << 'EOF'
#!/bin/bash
case "$*" in
    "list-unit-files asusd.service") echo "asusd.service enabled"; exit 0 ;;
    "list-unit-files asus-shutdown.service") exit 1 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "${WORKDIR}/bin/systemctl"

    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]

    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"mock: udevadm control --reload"* ]]
    [[ "${output}" != *"ASUS hardware detected"* ]]
}

@test "11-asus: records the version after a successful run" {
    echo "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]
    run jq -r '.version.system.asus' "${SETUP_CHECKER_FILE}"
    [ "${output}" = "1" ]
}

@test "11-asus: skips when asusd.service not installed" {
    echo "ASUSTeK COMPUTER INC." > "${WORKDIR}/sys/devices/virtual/dmi/id/sys_vendor"
    # Override systemctl to report asusd.service not found
    cat > "${WORKDIR}/bin/systemctl" << 'EOF'
#!/bin/bash
case "$*" in
    "list-unit-files asusd.service") exit 1 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "${WORKDIR}/bin/systemctl"

    run bash "${ASUS_HOOK}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"not present yet"* ]]
}
