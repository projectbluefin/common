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
# Wrapper smoke tests — config/fallback/missing-dir logic lives in hookrunner
# ---------------------------------------------------------------------------

_smoke() {
  local wrapper="$1" key="$2"
  export HOOKS_DIR="${WORKDIR}/${key}"
  mkdir -p "${HOOKS_DIR}"
  printf '#!/bin/bash\necho ran > %s/result\n' "${WORKDIR}" > "${HOOKS_DIR}/01-test.sh"
  chmod +x "${HOOKS_DIR}/01-test.sh"
  export SETUP_CONFIG_FILE="${WORKDIR}/setup.json"
  echo "{\"${key}\": \"${HOOKS_DIR}\"}" > "${SETUP_CONFIG_FILE}"
  bash "${wrapper}"
  [ -f "${WORKDIR}/result" ]
}

@test "ublue-system-setup: runs hooks from its configured directory" {
  _smoke "${SYSTEM_SETUP}" system-hooks-directory
}

@test "ublue-user-setup: runs hooks from its configured directory" {
  _smoke "${USER_SETUP}" user-hooks-directory
}

@test "ublue-privileged-setup: runs hooks from its configured directory" {
  _smoke "${PRIVILEGED_SETUP}" privileged-hooks-directory
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

@test "hookrunner: exits cleanly when hooks directory is missing" {
  export SETUP_CONFIG_FILE="${WORKDIR}/nonexistent.json"
  bash -c "source ${HOOKRUNNER_LIB@Q}; run_setup_hooks custom-hooks-directory /nonexistent/hooks"
}

@test "hookrunner: hook paths with spaces are handled safely" {
  export HOOKS_DIR="${WORKDIR}/hooks dir with spaces"
  mkdir -p "${HOOKS_DIR}"
  printf '#!/bin/bash\necho space > %q/space_result\n' "${WORKDIR}" > "${HOOKS_DIR}/01-space.sh"
  export SETUP_CONFIG_FILE="${WORKDIR}/nonexistent.json"

  bash -c "source ${HOOKRUNNER_LIB@Q}; run_setup_hooks custom-hooks-directory ${HOOKS_DIR@Q}"
  [ -f "${WORKDIR}/space_result" ]
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
