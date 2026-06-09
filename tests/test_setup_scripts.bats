#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/ublue-system-setup
# and system_files/shared/usr/bin/ublue-user-setup
#
# Run: bats tests/test_setup_scripts.bats

SYSTEM_SETUP="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ublue-system-setup"
USER_SETUP="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ublue-user-setup"
WORKDIR=""

setup() {
  WORKDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# ublue-system-setup
# ---------------------------------------------------------------------------

@test "ublue-system-setup: get_config returns fallback when config file missing" {
  export SETUP_CONFIG_FILE="${WORKDIR}/nonexistent.json"
  result="$(bash -c "
    source ${SYSTEM_SETUP@Q}
    get_config '.\"system-hooks-directory\"' '/default/path'
  ")"
  [ "${result}" = "/default/path" ]
}

@test "ublue-system-setup: get_config reads value from json file" {
  export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
  echo '{"system-hooks-directory": "/custom/hooks"}' > "${SETUP_CONFIG_FILE}"
  result="$(bash -c "
    source ${SYSTEM_SETUP@Q}
    get_config '.\"system-hooks-directory\"' '/default/path'
  ")"
  [ "${result}" = "/custom/hooks" ]
}

@test "ublue-system-setup: get_config returns fallback for null json value" {
  export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
  echo '{"system-hooks-directory": null}' > "${SETUP_CONFIG_FILE}"
  result="$(bash -c "
    source ${SYSTEM_SETUP@Q}
    get_config '.\"system-hooks-directory\"' '/default/path'
  ")"
  [ "${result}" = "/default/path" ]
}

@test "ublue-system-setup: runs hooks in hooks directory" {
  export HOOKS_DIR="${WORKDIR}/hooks"
  mkdir -p "${HOOKS_DIR}"
  echo "#!/bin/bash" > "${HOOKS_DIR}/01-test.sh"
  echo "echo hook_ran > ${WORKDIR}/result" >> "${HOOKS_DIR}/01-test.sh"
  chmod +x "${HOOKS_DIR}/01-test.sh"

  export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
  echo "{\"system-hooks-directory\": \"${HOOKS_DIR}\"}" > "${SETUP_CONFIG_FILE}"

  bash "${SYSTEM_SETUP}"
  [ -f "${WORKDIR}/result" ]
}

@test "ublue-system-setup: exits cleanly when hooks directory missing" {
  export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
  echo '{"system-hooks-directory": "/nonexistent/hooks"}' > "${SETUP_CONFIG_FILE}"
  run bash "${SYSTEM_SETUP}"
  [ "${status}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# ublue-user-setup
# ---------------------------------------------------------------------------

@test "ublue-user-setup: get_config returns fallback when config file missing" {
  export SETUP_CONFIG_FILE="${WORKDIR}/nonexistent.json"
  result="$(bash -c "
    source ${USER_SETUP@Q}
    get_config '.\"user-hooks-directory\"' '/default/user/path'
  ")"
  [ "${result}" = "/default/user/path" ]
}

@test "ublue-user-setup: get_config reads value from json file" {
  export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
  echo '{"user-hooks-directory": "/custom/user/hooks"}' > "${SETUP_CONFIG_FILE}"
  result="$(bash -c "
    source ${USER_SETUP@Q}
    get_config '.\"user-hooks-directory\"' '/default/user/path'
  ")"
  [ "${result}" = "/custom/user/hooks" ]
}

@test "ublue-user-setup: runs user hooks in hooks directory" {
  export HOOKS_DIR="${WORKDIR}/user-hooks"
  mkdir -p "${HOOKS_DIR}"
  echo "#!/bin/bash" > "${HOOKS_DIR}/01-user.sh"
  echo "echo user_hook_ran > ${WORKDIR}/user_result" >> "${HOOKS_DIR}/01-user.sh"
  chmod +x "${HOOKS_DIR}/01-user.sh"

  export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
  echo "{\"user-hooks-directory\": \"${HOOKS_DIR}\"}" > "${SETUP_CONFIG_FILE}"

  bash "${USER_SETUP}"
  [ -f "${WORKDIR}/user_result" ]
}

@test "ublue-user-setup: exits cleanly when hooks directory missing" {
  export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
  echo '{"user-hooks-directory": "/nonexistent/user/hooks"}' > "${SETUP_CONFIG_FILE}"
  run bash "${USER_SETUP}"
  [ "${status}" -eq 0 ]
}
