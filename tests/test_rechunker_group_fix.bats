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
