#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/ublue-privileged-setup
#
# Run: bats tests/test_privileged_setup.bats

PRIVILEGED_SETUP="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ublue-privileged-setup"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "ublue-privileged-setup: get_config returns fallback when config file missing" {
    export SETUP_CONFIG_FILE="${WORKDIR}/nonexistent.json"
    result="$(bash -c "
        source ${PRIVILEGED_SETUP@Q}
        get_config '.\"privileged-hooks-directory\"' '/default/privileged/path'
    ")"
    [ "${result}" = "/default/privileged/path" ]
}

@test "ublue-privileged-setup: get_config reads privileged-hooks-directory from json" {
    export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
    echo '{"privileged-hooks-directory": "/custom/privileged/hooks"}' > "${SETUP_CONFIG_FILE}"
    result="$(bash -c "
        source ${PRIVILEGED_SETUP@Q}
        get_config '.\"privileged-hooks-directory\"' '/default/privileged/path'
    ")"
    [ "${result}" = "/custom/privileged/hooks" ]
}

@test "ublue-privileged-setup: get_config returns fallback for null json value" {
    export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
    echo '{"privileged-hooks-directory": null}' > "${SETUP_CONFIG_FILE}"
    result="$(bash -c "
        source ${PRIVILEGED_SETUP@Q}
        get_config '.\"privileged-hooks-directory\"' '/default/privileged/path'
    ")"
    [ "${result}" = "/default/privileged/path" ]
}

@test "ublue-privileged-setup: executes hooks in configured directory" {
    export HOOKS_DIR="${WORKDIR}/privileged-hooks"
    mkdir -p "${HOOKS_DIR}"
    echo "#!/bin/bash" > "${HOOKS_DIR}/01-test.sh"
    echo "echo privileged_hook_ran > ${WORKDIR}/result" >> "${HOOKS_DIR}/01-test.sh"
    chmod +x "${HOOKS_DIR}/01-test.sh"

    export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
    echo "{\"privileged-hooks-directory\": \"${HOOKS_DIR}\"}" > "${SETUP_CONFIG_FILE}"

    bash "${PRIVILEGED_SETUP}"
    [ -f "${WORKDIR}/result" ]
}

@test "ublue-privileged-setup: exits cleanly when hooks directory is missing" {
    export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
    echo '{"privileged-hooks-directory": "/nonexistent/privileged/hooks"}' > "${SETUP_CONFIG_FILE}"
    run bash "${PRIVILEGED_SETUP}"
    [ "${status}" -eq 0 ]
}

@test "ublue-privileged-setup: hook paths with spaces are handled safely" {
    export HOOKS_DIR="${WORKDIR}/privileged hooks dir"
    mkdir -p "${HOOKS_DIR}"
    echo "#!/bin/bash" > "${HOOKS_DIR}/01-space-test.sh"
    echo "echo space_hook_ran > ${WORKDIR}/space_result" >> "${HOOKS_DIR}/01-space-test.sh"
    chmod +x "${HOOKS_DIR}/01-space-test.sh"

    export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
    printf '{"privileged-hooks-directory": "%s"}' "${HOOKS_DIR}" > "${SETUP_CONFIG_FILE}"

    bash "${PRIVILEGED_SETUP}"
    [ -f "${WORKDIR}/space_result" ]
}
