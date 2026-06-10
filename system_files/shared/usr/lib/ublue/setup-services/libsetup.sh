#!/usr/bin/env bash

SETUP_CHECKER_FILE="${SETUP_CHECKER_FILE:-$HOME/.local/share/ublue/setup_versioning.json}"

# Meant to be used at the start of any setup service script. Will version your script accordingly on $SETUP_CHECKER_FILE
# :target_versioning_name: Whatever you want to name your versioning tag. Please keep it always the same
# :type_of_service: Must be either `user`, `privileged`, or `system`
# :version: Target version to check/apply to your file
#
# Meant to be used as follows (or similar):
# version-script tailscale user 1 || exit 0
function version-script() {
  TARGET_VERSIONING_NAME=$1
  TYPE_OF_SERVICE=$2
  VERSION=$3
  shift 3

  local lock_file="${SETUP_CHECKER_FILE}.lock"

  # Run the check/write inside a subshell with an exclusive flock so that
  # concurrent first-boot setup scripts (user-setup + privileged-setup) cannot
  # read the JSON before either has written back, causing duplicate execution.
  (
    flock -x 200

    if [ ! -e "${SETUP_CHECKER_FILE}" ]; then
      mkdir -p "$(dirname "${SETUP_CHECKER_FILE}")"
      echo "{}" > "${SETUP_CHECKER_FILE}"
    fi

    # Validate JSON; reset if malformed rather than silently skipping setup.
    if ! jq '.' "${SETUP_CHECKER_FILE}" >/dev/null 2>&1; then
      echo "Warning: ${SETUP_CHECKER_FILE} is malformed; resetting."
      echo "{}" > "${SETUP_CHECKER_FILE}"
    fi

    if [ "$(jq -r -c ".version.${TYPE_OF_SERVICE}.\"${TARGET_VERSIONING_NAME}\"" "${SETUP_CHECKER_FILE}")" == "${VERSION}" ]; then
      echo "Exiting as current version (${VERSION}) for ${TYPE_OF_SERVICE}-${TARGET_VERSIONING_NAME} is the same as latest version recorded on ${SETUP_CHECKER_FILE}"
      exit 1
    fi

    local tmp
    tmp=$(mktemp)
    # Remove the temp file on any exit from this subshell (normal or error).
    trap 'rm -f "${tmp}"' EXIT

    if jq ".version.${TYPE_OF_SERVICE}.\"${TARGET_VERSIONING_NAME}\" = \"${VERSION}\"" "${SETUP_CHECKER_FILE}" > "${tmp}"; then
      mv "${tmp}" "${SETUP_CHECKER_FILE}"
    else
      echo "Error: failed to write version update for ${TYPE_OF_SERVICE}-${TARGET_VERSIONING_NAME}"
      exit 1
    fi

    exit 0
  ) 200>"${lock_file}"

  return $?
}
