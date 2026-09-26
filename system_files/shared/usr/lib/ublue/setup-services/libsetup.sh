#!/usr/bin/env bash

SETUP_CHECKER_FILE="${SETUP_CHECKER_FILE:-$HOME/.local/share/ublue/setup_versioning.json}"

# Meant to be used at the start of any setup service script. Will version your script accordingly on $SETUP_CHECKER_FILE
# :target_versioning_name: Whatever you want to name your versioning tag. Please keep it always the same
# :type_of_service: Must be either `user`, `privileged`, or `system`
# :version: Target version to check/apply to your file
#
# Meant to be used as follows (or similar):
#   version-script tailscale user 1 || exit 0      # read-only gate at the top of the hook
#   ... your setup work ...
#   version-script-commit tailscale user 1         # record success at the end, only on success
#
# version-script is a pure read: it tells the caller whether the hook has run
# at this version yet, but it does NOT record anything. version-script-commit
# records the version, so a hook whose body fails (offline machine, masked unit,
# missing package) never reaches the commit and retries on the next boot instead
# of being permanently, silently skipped.
function version-script() {
  TARGET_VERSIONING_NAME=$1
  TYPE_OF_SERVICE=$2
  VERSION=$3

  # Ensure the checker file exists and is valid JSON (shared with the commit).
  _setup_versioning_file

  if [ "$(jq -r -c ".version.${TYPE_OF_SERVICE}.\"${TARGET_VERSIONING_NAME}\"" "${SETUP_CHECKER_FILE}")" == "${VERSION}" ]; then
    echo "Exiting as current version (${VERSION}) for ${TYPE_OF_SERVICE}-${TARGET_VERSIONING_NAME} is the same as latest version recorded on ${SETUP_CHECKER_FILE}"
    return 1
  fi

  # Gate only — do not record here. The caller records success with
  # version-script-commit once its body has run without failing.
  return 0
}

# version-script-commit <name> <type> <n>
# Records the version on success. Call this at the end of a hook body, and only
# when the work succeeded, so a failed first-boot hook retries next boot rather
# than being permanently skipped. See version-script (the read-only gate).
function version-script-commit() {
  TARGET_VERSIONING_NAME=$1
  TYPE_OF_SERVICE=$2
  VERSION=$3

  # Hold the exclusive lock across the whole read-modify-write (create/validate
  # + jq + mv) so two hooks committing to the same SETUP_CHECKER_FILE cannot
  # clobber each other's stamp — a lost update would silently re-run the hook
  # on the next boot. This restores the lock the original version-script held.
  local lock_file="${SETUP_CHECKER_FILE}.lock"
  (
    flock -x 200

    _ensure_versioning_file

    tmp=$(mktemp)
    if jq ".version.${TYPE_OF_SERVICE}.\"${TARGET_VERSIONING_NAME}\" = \"${VERSION}\"" "${SETUP_CHECKER_FILE}" > "${tmp}"; then
      mv "${tmp}" "${SETUP_CHECKER_FILE}"
    else
      rm -f "${tmp}"
      echo "Error: failed to write version update for ${TYPE_OF_SERVICE}-${TARGET_VERSIONING_NAME}"
      return 1
    fi
  ) 200>"${lock_file}" || return 1
}

# _ensure_versioning_file
#
# Ensure $SETUP_CHECKER_FILE exists and holds valid JSON, resetting if it is
# malformed rather than silently skipping setup. Takes NO lock; callers that
# also write must hold the lock themselves so the create/validate and the
# read-modify-write are atomic together.
_ensure_versioning_file() {
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

# _setup_versioning_file
#
# Locking wrapper around _ensure_versioning_file: takes an exclusive lock so
# concurrent first-boot setup scripts (user-setup + privileged-setup) cannot
# read the JSON before either has written back, causing duplicate execution.
# Used by version-script (the read gate), which only reads.
_setup_versioning_file() {
  local lock_file="${SETUP_CHECKER_FILE}.lock"
  (
    flock -x 200
    _ensure_versioning_file
  ) 200>"${lock_file}"
}
