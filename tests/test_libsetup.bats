#!/usr/bin/env bats
# Tests for system_files/shared/usr/lib/ublue/setup-services/libsetup.sh
#
# Run: bats tests/test_libsetup.bats

LIBSETUP="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/ublue/setup-services/libsetup.sh"
WORKDIR=""

setup() {
  WORKDIR="$(mktemp -d)"
  export SETUP_CHECKER_FILE="${WORKDIR}/setup_versioning.json"
}

teardown() {
  rm -rf "${WORKDIR}"
}

# Source libsetup into the current shell so version-script / version-script-commit are available
_source_lib() {
  # shellcheck source=/dev/null
  source "${LIBSETUP}"
}

# version-script is a pure read gate: it reports whether the hook has already
# run at this version, but records nothing itself. See projectbluefin/common#1137.
#
# version-script-commit records the version, and is the only thing that writes.

@test "version-script creates versioning file if missing" {
  _source_lib
  version-script my-service user 1
  [ -f "${SETUP_CHECKER_FILE}" ]
}

@test "version-script returns 0 (runs) on first call" {
  _source_lib
  run version-script my-service user 1
  [ "${status}" -eq 0 ]
}

@test "version-script does not record the version (gate only)" {
  _source_lib
  version-script my-service user 1
  [ "$(jq -r '.version.user."my-service"' "${SETUP_CHECKER_FILE}" 2>/dev/null)" = "null" ]
}

@test "version-script returns 1 (skips) when version matches" {
  _source_lib
  version-script-commit my-service user 1
  run version-script my-service user 1
  [ "${status}" -eq 1 ]
}

@test "version-script returns 0 (runs) on version bump" {
  _source_lib
  version-script-commit my-service user 1
  run version-script my-service user 2
  [ "${status}" -eq 0 ]
}

@test "version-script-commit records version in json" {
  _source_lib
  version-script-commit my-service user 1
  val="$(jq -r '.version.user."my-service"' "${SETUP_CHECKER_FILE}")"
  [ "${val}" = "1" ]
}

@test "version-script-commit records bumped version" {
  _source_lib
  version-script-commit my-service user 1
  version-script-commit my-service user 2
  val="$(jq -r '.version.user."my-service"' "${SETUP_CHECKER_FILE}")"
  [ "${val}" = "2" ]
}

@test "version-script-commit supports system type" {
  _source_lib
  version-script-commit svc system 3
  val="$(jq -r '.version.system."svc"' "${SETUP_CHECKER_FILE}")"
  [ "${val}" = "3" ]
}

@test "version-script-commit supports privileged type" {
  _source_lib
  version-script-commit svc privileged 5
  val="$(jq -r '.version.privileged."svc"' "${SETUP_CHECKER_FILE}")"
  [ "${val}" = "5" ]
}

@test "version-script-commit isolates services by name" {
  _source_lib
  version-script-commit svc-a user 1
  version-script-commit svc-b user 1
  run version-script svc-a user 1
  [ "${status}" -eq 1 ]
  run version-script svc-b user 1
  [ "${status}" -eq 1 ]
}

# Regression guard for projectbluefin/common#1137: the gate says "run" (0) but
# if the hook body fails it never calls version-script-commit, so the version
# stays unrecorded and the hook retries next boot.
@test "version-script-commit: a failed body does not record the version" {
  _source_lib
  run version-script my-service user 1
  [ "${status}" -eq 0 ]
  # (the body "fails" here = we never call version-script-commit)
  [ "$(jq -r '.version.user."my-service"' "${SETUP_CHECKER_FILE}" 2>/dev/null)" = "null" ]

  # a later successful run records the version and is treated as done
  version-script-commit my-service user 1
  [ "$(jq -r '.version.user."my-service"' "${SETUP_CHECKER_FILE}")" = "1" ]
  run version-script my-service user 1
  [ "${status}" -eq 1 ]
}

# Regression guard for projectbluefin/common#1196: version-script-commit must
# surface a write failure to the caller. A swallowed return (the subshell
# returned 1 but the function fell through to an unconditional `return 0`)
# meant a failed version stamp looked like success, so the hook would not
# retry. The commit has to propagate the subshell's non-zero status.
@test "version-script-commit returns non-zero when the write fails" {
  _source_lib
  # Point the versioning file at a directory so the write cannot succeed.
  mkdir "${SETUP_CHECKER_FILE}"
  run version-script-commit my-service user 1
  [ "${status}" -ne 0 ]
}
