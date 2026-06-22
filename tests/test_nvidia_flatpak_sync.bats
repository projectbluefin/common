#!/usr/bin/env bats
# Tests for system_files/nvidia/usr/libexec/ublue-nvidia-flatpak-runtime-sync
#
# The script supports:
#   NVIDIA_VERSION_FILE — path to nvidia version file (default: /sys/module/nvidia/version)
#
# Run: bats tests/test_nvidia_flatpak_sync.bats

SCRIPT="$BATS_TEST_DIRNAME/../system_files/nvidia/usr/libexec/ublue-nvidia-flatpak-runtime-sync"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"

    # Default: nvidia version 550.54.14
    echo "550.54.14" > "${WORKDIR}/nvidia_version"
    export NVIDIA_VERSION_FILE="${WORKDIR}/nvidia_version"

    # Default flatpak mock: runtime not installed (check returns 0 = needs sync)
    cat > "${WORKDIR}/bin/flatpak" << 'EOF'
#!/bin/bash
case "$1" in
    info)
        # Simulate runtime not installed
        exit 1
        ;;
    remote-add)
        echo "mock: flatpak remote-add $*" >&2
        exit 0
        ;;
    install)
        echo "mock: flatpak install $*" >&2
        exit 0
        ;;
    *)
        echo "mock: flatpak $*" >&2
        exit 0
        ;;
esac
EOF
    chmod +x "${WORKDIR}/bin/flatpak"

    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# check subcommand
# ---------------------------------------------------------------------------

@test "check: exits 0 when runtime not installed (sync needed)" {
    run bash "${SCRIPT}" check
    [ "${status}" -eq 0 ]
}

@test "check: exits 1 when runtime already installed (no sync needed)" {
    cat > "${WORKDIR}/bin/flatpak" << 'EOF'
#!/bin/bash
case "$1" in
    info)
        echo "org.freedesktop.Platform.GL.nvidia-550-54-14 installed"
        exit 0
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "${WORKDIR}/bin/flatpak"

    run bash "${SCRIPT}" check
    [ "${status}" -eq 1 ]
}

@test "check: prints sync-needed message when runtime not installed" {
    run bash "${SCRIPT}" check
    [[ "${output}" == *"needs to be installed"* ]]
}

@test "check: prints already-installed message when runtime present" {
    cat > "${WORKDIR}/bin/flatpak" << 'EOF'
#!/bin/bash
case "$1" in
    info) exit 0 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "${WORKDIR}/bin/flatpak"

    run bash "${SCRIPT}" check
    [[ "${output}" == *"already installed"* ]]
}

@test "check: converts dot notation to dash notation for flatpak package name" {
    echo "550.54.14" > "${WORKDIR}/nvidia_version"
    CALLS_FILE="${WORKDIR}/flatpak_check_calls"
    cat > "${WORKDIR}/bin/flatpak" << ENDSCRIPT
#!/bin/bash
echo "\$*" >> "${CALLS_FILE}"
exit 1
ENDSCRIPT
    chmod +x "${WORKDIR}/bin/flatpak"

    run bash "${SCRIPT}" check
    # Package name should use dashes, not dots
    grep -q "nvidia-550-54-14" "${CALLS_FILE}"
}

# ---------------------------------------------------------------------------
# sync subcommand
# ---------------------------------------------------------------------------

@test "sync: exits 0 and calls flatpak install" {
    run bash "${SCRIPT}" sync
    [ "${status}" -eq 0 ]
}

@test "sync: installs GL and GL32 runtime packages" {
    CALLS_FILE="${WORKDIR}/flatpak_calls"
    cat > "${WORKDIR}/bin/flatpak" << ENDSCRIPT
#!/bin/bash
echo "flatpak-called: \$*" >> "${CALLS_FILE}"
exit 0
ENDSCRIPT
    chmod +x "${WORKDIR}/bin/flatpak"

    run bash "${SCRIPT}" sync
    [ "${status}" -eq 0 ]
    grep -q "GL.nvidia" "${CALLS_FILE}"
    grep -q "GL32.nvidia" "${CALLS_FILE}"
}

@test "sync: prints installing message with version" {
    run bash "${SCRIPT}" sync
    [[ "${output}" == *"550.54.14"* ]]
}

# ---------------------------------------------------------------------------
# invalid subcommand
# ---------------------------------------------------------------------------

@test "invalid subcommand exits 1 with usage message" {
    run bash "${SCRIPT}" badarg
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Usage"* ]]
}

@test "no subcommand exits 1 with usage message" {
    run bash "${SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Usage"* ]]
}
