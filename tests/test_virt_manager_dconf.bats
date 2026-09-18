#!/usr/bin/env bats
# Tests for system_files/bluefin/etc/dconf/db/distro.d/06-bluefin-virt-manager-session
#
# virt-manager's Flatpak has no way to reach a system libvirtd/virtqemud
# socket on Bluefin (none is installed or enabled), so its default
# qemu:///system connection fails. This override must point it at
# qemu:///session instead, matching `ujust toggle-devmode`'s libvirt setup.

DCONF_OVERRIDE="$BATS_TEST_DIRNAME/../system_files/bluefin/etc/dconf/db/distro.d/06-bluefin-virt-manager-session"

@test "virt-manager dconf override: file exists" {
    [ -f "${DCONF_OVERRIDE}" ]
}

@test "virt-manager dconf override: targets the virt-manager schema path" {
    grep -qxF '[org/virt-manager/virt-manager]' "${DCONF_OVERRIDE}"
}

@test "virt-manager dconf override: defaults connections to qemu:///session" {
    grep -qxF "connections=['qemu:///session']" "${DCONF_OVERRIDE}"
}
