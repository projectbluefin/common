#!/usr/bin/env bash

SETUP_CHECKER_FILE="${SETUP_CHECKER_FILE:-$HOME/.local/share/ublue/setup_versioning.json}"

# Version gates for setup hooks, recorded in $SETUP_CHECKER_FILE.
# :target_versioning_name: Whatever you want to name your versioning tag. Please keep it always the same
# :type_of_service: Must be either `user`, `privileged`, or `system`
# :version: Target version to check/apply to your file
#
# Preferred for new and migrated hooks — record the version only on success:
#   version-script-check tailscale user 1 || exit 0   # read-only gate at the top of the hook
#   ... your setup work ...
#   version-script-commit tailscale user 1            # record success at the end, only on success
#
# version-script-check records nothing, so a hook whose body fails (offline
# machine, masked unit, missing package) never reaches the commit and retries
# on the next boot instead of being permanently, silently skipped
# (projectbluefin/common#1137).
#
# Note: check and commit take the lock independently, so the pair is NOT
# mutually exclusive across processes — two concurrent runs of the same hook
# with the same key can both pass the gate before either commits. Unlike
# version-script, which checks and records under one lock, the split API only
# guarantees that each individual read or write is atomic. hookrunner runs
# hooks sequentially per service and the user/system/privileged keys differ, so
# this does not happen in practice; keep it in mind for new callers.
#
# Legacy check-and-record, kept unchanged for existing callers (including
# downstream images that ship this library):
#   version-script tailscale user 1 || exit 0
# version-script records the version before the hook body runs, so a failing
# body is still skipped on later runs. Migrate hooks to the pair above.
function version-script() {
  TARGET_VERSIONING_NAME=$1
  TYPE_OF_SERVICE=$2
  VERSION=$3
  shift 3

  local lock_file="${SETUP_CHECKER_FILE}.lock"

  # Ensure the lock file's parent directory exists before opening fd 200 on it.
  # The redirection is evaluated before the subshell body runs, so a missing
  # directory (e.g. /root/.local/share/ublue on first login) would fail the
  # flock with "No such file or directory" and skip the hook silently. See
  # projectbluefin/common#1325.
  mkdir -p "$(dirname "${lock_file}")"

  # Run the check/write inside a subshell with an exclusive flock so that
  # concurrent first-boot setup scripts (user-setup + privileged-setup) cannot
  # read the JSON before either has written back, causing duplicate execution.
  (
    flock -x 200

    _ensure_versioning_file

    if [ "$(jq -r -c ".version.${TYPE_OF_SERVICE}.\"${TARGET_VERSIONING_NAME}\"" "${SETUP_CHECKER_FILE}")" == "${VERSION}" ]; then
      echo "Exiting as current version (${VERSION}) for ${TYPE_OF_SERVICE}-${TARGET_VERSIONING_NAME} is the same as latest version recorded on ${SETUP_CHECKER_FILE}"
      exit 1
    fi

    _write_version
  ) 200>"${lock_file}"

  return $?
}

# version-script-check <name> <type> <n>
# Read-only gate: returns 1 if the hook already ran at this version, 0 if it
# should run. Records no version; pair it with version-script-commit.
function version-script-check() {
  TARGET_VERSIONING_NAME=$1
  TYPE_OF_SERVICE=$2
  VERSION=$3

  # Hold the exclusive lock across create/validate and the version read so a
  # concurrent version-script-commit cannot stamp between _ensure_versioning_file
  # and the jq read. The atomic mv in _write_version prevents a torn read, but
  # holding the lock makes the check-and-return a single atomic step.
  local lock_file="${SETUP_CHECKER_FILE}.lock"
  mkdir -p "$(dirname "${lock_file}")"
  (
    flock -x 200
    _ensure_versioning_file
    if [ "$(jq -r -c ".version.${TYPE_OF_SERVICE}.\"${TARGET_VERSIONING_NAME}\"" "${SETUP_CHECKER_FILE}")" == "${VERSION}" ]; then
      echo "Exiting as current version (${VERSION}) for ${TYPE_OF_SERVICE}-${TARGET_VERSIONING_NAME} is the same as latest version recorded on ${SETUP_CHECKER_FILE}"
      exit 1
    fi
    exit 0
  ) 200>"${lock_file}"
}

# version-script-commit <name> <type> <n>
# Records the version on success. Call this at the end of a hook body, and only
# when the work succeeded, so a failed first-boot hook retries next boot rather
# than being permanently skipped. See version-script-check (the read-only gate).
function version-script-commit() {
  TARGET_VERSIONING_NAME=$1
  TYPE_OF_SERVICE=$2
  VERSION=$3

  # Hold the exclusive lock across the whole read-modify-write (create/validate
  # + jq + mv) so two hooks committing to the same SETUP_CHECKER_FILE cannot
  # clobber each other's stamp — a lost update would silently re-run the hook
  # on the next boot.
  local lock_file="${SETUP_CHECKER_FILE}.lock"
  mkdir -p "$(dirname "${lock_file}")"
  (
    flock -x 200

    _ensure_versioning_file
    _write_version
  ) 200>"${lock_file}" || return 1
}

# _write_version
#
# Record ${VERSION} for ${TYPE_OF_SERVICE}.${TARGET_VERSIONING_NAME} in
# $SETUP_CHECKER_FILE. Takes NO lock; callers must hold it. Returns non-zero
# if the write fails.
function _write_version() {
  local tmp
  tmp=$(mktemp)
  if jq ".version.${TYPE_OF_SERVICE}.\"${TARGET_VERSIONING_NAME}\" = \"${VERSION}\"" "${SETUP_CHECKER_FILE}" > "${tmp}"; then
    mv "${tmp}" "${SETUP_CHECKER_FILE}" || {
      rm -f "${tmp}"
      echo "Error: failed to install version update for ${TYPE_OF_SERVICE}-${TARGET_VERSIONING_NAME}"
      return 1
    }
  else
    rm -f "${tmp}"
    echo "Error: failed to write version update for ${TYPE_OF_SERVICE}-${TARGET_VERSIONING_NAME}"
    return 1
  fi
}

# _ensure_versioning_file
#
# Ensure $SETUP_CHECKER_FILE exists and holds valid JSON, resetting if it is
# malformed rather than silently skipping setup. Takes NO lock; callers that
# also write must hold the lock themselves so the create/validate and the
# read-modify-write are atomic together.
function _ensure_versioning_file() {
  if [ ! -e "${SETUP_CHECKER_FILE}" ]; then
    mkdir -p "$(dirname "${SETUP_CHECKER_FILE}")"
    echo "{}" > "${SETUP_CHECKER_FILE}"
  fi

  # Validate JSON; reset if malformed rather than silently skipping setup.
  if ! jq '.' "${SETUP_CHECKER_FILE}" >/dev/null 2>&1; then
    echo "Warning: ${SETUP_CHECKER_FILE} is malformed; resetting."
    echo "{}" > "${SETUP_CHECKER_FILE}"
  fi
}
