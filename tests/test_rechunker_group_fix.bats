#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/rechunker-group-fix
#
# Run: bats tests/test_rechunker_group_fix.bats

SCRIPT="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/rechunker-group-fix"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    export GROUP_FILE="${WORKDIR}/group"
    export GSHADOW_FILE="${WORKDIR}/gshadow"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# Basic behaviour
# ---------------------------------------------------------------------------

@test "rechunker-group-fix: appends missing group to empty gshadow" {
    printf 'wheel:x:10:user\n' > "${GROUP_FILE}"
    touch "${GSHADOW_FILE}"

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "^wheel:!\*::" "${GSHADOW_FILE}"
}

@test "rechunker-group-fix: does not duplicate entry already in gshadow" {
    printf 'wheel:x:10:user\n' > "${GROUP_FILE}"
    printf 'wheel:!*::\n' > "${GSHADOW_FILE}"

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    count=$(grep -c "^wheel:" "${GSHADOW_FILE}")
    [ "${count}" -eq 1 ]
}

@test "rechunker-group-fix: appends only missing entries in multi-group file" {
    printf 'wheel:x:10:\ndocker:x:999:\nvideo:x:44:\n' > "${GROUP_FILE}"
    printf 'wheel:!*::\n' > "${GSHADOW_FILE}"

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "^docker:!\*::" "${GSHADOW_FILE}"
    grep -q "^video:!\*::" "${GSHADOW_FILE}"
    count=$(grep -c "^wheel:" "${GSHADOW_FILE}")
    [ "${count}" -eq 1 ]
}

@test "rechunker-group-fix: handles empty group file gracefully" {
    touch "${GROUP_FILE}"
    touch "${GSHADOW_FILE}"

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ ! -s "${GSHADOW_FILE}" ]
}

@test "rechunker-group-fix: creates gshadow file if it does not exist" {
    printf 'newgroup:x:500:\n' > "${GROUP_FILE}"
    # GSHADOW_FILE does not exist yet

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${GSHADOW_FILE}" ]
    grep -q "^newgroup:!\*::" "${GSHADOW_FILE}"
}

@test "rechunker-group-fix: written entry has correct gshadow format (group:!*::)" {
    printf 'testgrp:x:1234:alice,bob\n' > "${GROUP_FILE}"
    touch "${GSHADOW_FILE}"

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qE "^testgrp:!\*::$" "${GSHADOW_FILE}"
}

@test "rechunker-group-fix: processes all groups from file with no pre-existing gshadow entries" {
    printf 'alpha:x:1:\nbeta:x:2:\ngamma:x:3:\n' > "${GROUP_FILE}"
    touch "${GSHADOW_FILE}"

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "^alpha:" "${GSHADOW_FILE}"
    grep -q "^beta:" "${GSHADOW_FILE}"
    grep -q "^gamma:" "${GSHADOW_FILE}"
}

# ---------------------------------------------------------------------------
# Unit ordering regression — common#918 / bluefin-lts#391
#
# rechunker-group-fix.service is an early-boot unit (DefaultDependencies=no)
# that must run before systemd-sysusers.service. Pulling in Wants=local-fs.target
# / After=local-fs.target created an ordering cycle:
#
#   local-fs.target -> this unit -> systemd-sysusers.service ->
#   systemd-tmpfiles-setup-dev.service -> local-fs-pre.target -> local-fs.target
#
# systemd broke it by deleting local-fs-pre.target, leaving /var and other
# fstab mounts unmounted and hanging the boot. These tests are static checks on
# the unit file: they assert the local-fs edges are absent and that the
# writable-/etc, pre-systemd-sysusers and bootc-coexistence guarantees plus the
# gshadow repair sequence are intact. They do not simulate the boot transaction —
# proof that the cycle is gone requires `systemd-analyze verify` on a booted
# system or a VM boot.
# ---------------------------------------------------------------------------

UNIT="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/systemd/system/rechunker-group-fix.service"

@test "rechunker unit: carries no local-fs ordering edge (cycle edge removed)" {
    # Strip comment lines, then assert no local-fs reference remains in active
    # config. (The explanatory comment deliberately mentions local-fs.target.)
    ! grep -v '^[[:space:]]*#' "${UNIT}" | grep -q 'local-fs'
}

@test "rechunker unit: never acquires a local-fs target ordering edge (regression guard)" {
    # Future edits must not reintroduce a local-fs mount-target edge. Edges to
    # other targets (sysinit.target, shutdown.target, ...) are cycle-free and
    # allowed — systemd-sysusers.service itself carries them.
    edges="$(grep -vE '^[[:space:]]*#' "${UNIT}" | grep -E '^(After|Before|Wants|Requires)=')"
    while IFS= read -r edge; do
        [ -z "${edge}" ] && continue
        dep="${edge#*=}"
        for u in ${dep}; do
            case "${u}" in
                local-fs*.target)
                    echo "local-fs target edge reintroduces the common#918 cycle: ${edge}" >&2
                    return 1
                    ;;
            esac
        done
    done <<<"${edges}"
}

@test "rechunker unit: orders after the units that make /etc writable" {
    # bootc-sysusers-shadow-sync.service is absent on rpm-ostree images and on
    # bootc < 1.16, so the writable-/etc guarantee must be declared directly.
    grep -q '^After=systemd-remount-fs.service' "${UNIT}"
    grep -q '^After=systemd-tmpfiles-setup-dev-early.service' "${UNIT}"
}

@test "rechunker unit: tmpfiles pass is scoped to /etc (no /var before var.mount)" {
    # This unit runs before local-fs-pre.target, so /var is unmounted here; an
    # unscoped --create --remove pass fails with EROFS every boot.
    line="$(grep -E '^ExecStart=systemd-tmpfiles' "${UNIT}")"
    [[ "${line}" == *"--prefix=/etc"* ]]
}

@test "rechunker unit: passes systemd-analyze verify" {
    # Syntax/directive validation only — systemd-analyze cannot resolve the
    # boot-time ordering graph offline, so this does not by itself prove the
    # cycle is gone. See tests/README or the PR discussion for VM evidence.
    command -v systemd-analyze >/dev/null 2>&1 || skip "systemd-analyze not available"
    run systemd-analyze verify --recursive-errors=no "${UNIT}"
    [ "${status}" -eq 0 ]
}

@test "rechunker unit: preserves the pre-systemd-sysusers guarantee" {
    grep -q '^Before=systemd-sysusers.service' "${UNIT}"
}

@test "rechunker unit: preserves coexistence with bootc-sysusers-shadow-sync" {
    grep -q '^After=bootc-sysusers-shadow-sync.service' "${UNIT}"
}

@test "rechunker unit: keeps DefaultDependencies=no and the ostree condition" {
    grep -q '^DefaultDependencies=no' "${UNIT}"
    grep -q '^ConditionPathExists=/run/ostree-booted' "${UNIT}"
}

@test "rechunker unit: still declares the full gshadow repair sequence" {
    # Legacy-rechunked upgrades must still reconstruct /etc/gshadow on boot.
    grep -q 'touch /etc/gshadow' "${UNIT}"
    grep -q '^ExecStart=systemd-sysusers' "${UNIT}"
    grep -q '^ExecStart=rechunker-group-fix' "${UNIT}"
    grep -q 'systemd-tmpfiles --create --remove --boot' "${UNIT}"
}
