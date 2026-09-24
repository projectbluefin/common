#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/ublue-system-setup,
# system_files/shared/usr/bin/ublue-user-setup and the shared dispatcher in
# system_files/shared/usr/lib/ublue/setup-services/hookrunner.sh
#
# Run: bats tests/test_setup_scripts.bats

SYSTEM_SETUP="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ublue-system-setup"
USER_SETUP="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ublue-user-setup"
PRIVILEGED_SETUP="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ublue-privileged-setup"
HOOKRUNNER_LIB="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/ublue/setup-services/hookrunner.sh"
WORKDIR=""

setup() {
  WORKDIR="$(mktemp -d)"
  # The wrappers source the shared dispatcher from its installed location by
  # default; point them at the checkout copy instead.
  export HOOKRUNNER="${HOOKRUNNER_LIB}"
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

# ---------------------------------------------------------------------------
# hookrunner.sh — the single source of truth the three wrappers share
# ---------------------------------------------------------------------------

@test "hookrunner: run_setup_hooks reads its directory from the given config key" {
  export HOOKS_DIR="${WORKDIR}/keyed-hooks"
  mkdir -p "${HOOKS_DIR}"
  printf '#!/bin/bash\necho keyed > %s/keyed_result\n' "${WORKDIR}" > "${HOOKS_DIR}/01-keyed.sh"

  export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
  echo "{\"custom-hooks-directory\": \"${HOOKS_DIR}\"}" > "${SETUP_CONFIG_FILE}"

  bash -c "source ${HOOKRUNNER_LIB@Q}; run_setup_hooks custom-hooks-directory /nonexistent/default"
  [ -f "${WORKDIR}/keyed_result" ]
}

@test "hookrunner: run_setup_hooks falls back to the given default directory" {
  export HOOKS_DIR="${WORKDIR}/default-hooks"
  mkdir -p "${HOOKS_DIR}"
  printf '#!/bin/bash\necho fallback > %s/fallback_result\n' "${WORKDIR}" > "${HOOKS_DIR}/01-fallback.sh"

  export SETUP_CONFIG_FILE="${WORKDIR}/nonexistent.json"

  bash -c "source ${HOOKRUNNER_LIB@Q}; run_setup_hooks custom-hooks-directory ${HOOKS_DIR@Q}"
  [ -f "${WORKDIR}/fallback_result" ]
}

@test "hookrunner: run_setup_hooks executes hooks in glob order" {
  export HOOKS_DIR="${WORKDIR}/ordered-hooks"
  mkdir -p "${HOOKS_DIR}"
  printf '#!/bin/bash\necho a >> %s/order\n' "${WORKDIR}" > "${HOOKS_DIR}/10-a.sh"
  printf '#!/bin/bash\necho b >> %s/order\n' "${WORKDIR}" > "${HOOKS_DIR}/20-b.sh"

  export SETUP_CONFIG_FILE="${WORKDIR}/nonexistent.json"

  bash -c "source ${HOOKRUNNER_LIB@Q}; run_setup_hooks custom-hooks-directory ${HOOKS_DIR@Q}"
  [ "$(tr '\n' ' ' < "${WORKDIR}/order")" = "a b " ]
}

# ---------------------------------------------------------------------------
# Structural guard — keep the wrappers thin
#
# These three entry points were byte-identical copies of one another for a long
# time, which is how a defect in the dispatch loop got shipped three times.
# Fail loudly if anyone reintroduces a private copy of the dispatcher.
# ---------------------------------------------------------------------------

@test "setup wrappers: none defines its own get_config or dispatch loop" {
  for wrapper in "${SYSTEM_SETUP}" "${USER_SETUP}" "${PRIVILEGED_SETUP}"; do
    run grep -Eq '^[[:space:]]*(get_config[[:space:]]*\(\)|function[[:space:]]+get_config)' "${wrapper}"
    [ "${status}" -ne 0 ]
    run grep -q 'for script in' "${wrapper}"
    [ "${status}" -ne 0 ]
  done
}

@test "setup wrappers: all three source the same hookrunner library" {
  for wrapper in "${SYSTEM_SETUP}" "${USER_SETUP}" "${PRIVILEGED_SETUP}"; do
    grep -q 'HOOKRUNNER="${HOOKRUNNER:-/usr/lib/ublue/setup-services/hookrunner.sh}"' "${wrapper}"
    grep -q 'run_setup_hooks ' "${wrapper}"
  done
}
