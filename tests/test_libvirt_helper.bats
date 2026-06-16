#!/usr/bin/env bats
# Tests for system_files/bluefin/usr/libexec/ensure-libvirt-session-config

LIBVIRT_HELPER="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/libexec/ensure-libvirt-session-config"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    export HOME="${WORKDIR}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "ensure-libvirt-session-config: writes qemu session default" {
    run bash "${LIBVIRT_HELPER}"
    [ "${status}" -eq 0 ]
    grep -qxF 'uri_default = "qemu:///session"' "${WORKDIR}/.config/libvirt/libvirt.conf"
}

@test "ensure-libvirt-session-config: is idempotent" {
    bash "${LIBVIRT_HELPER}"
    bash "${LIBVIRT_HELPER}"

    run grep -c '^uri_default = "qemu:///session"$' "${WORKDIR}/.config/libvirt/libvirt.conf"
    [ "${status}" -eq 0 ]
    [ "${output}" = "1" ]
}
