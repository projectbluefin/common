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

# Source libsetup into the current shell so version-script is available
_source_lib() {
  # shellcheck source=/dev/null
  source "${LIBSETUP}"
}

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

@test "version-script records version in json" {
  _source_lib
  version-script my-service user 1
  val="$(jq -r '.version.user."my-service"' "${SETUP_CHECKER_FILE}")"
  [ "${val}" = "1" ]
}

@test "version-script returns 1 (skips) when version matches" {
  _source_lib
  version-script my-service user 1
  run version-script my-service user 1
  [ "${status}" -eq 1 ]
}

@test "version-script returns 0 (runs) on version bump" {
  _source_lib
  version-script my-service user 1
  run version-script my-service user 2
  [ "${status}" -eq 0 ]
}

@test "version-script records bumped version" {
  _source_lib
  version-script my-service user 1
  version-script my-service user 2
  val="$(jq -r '.version.user."my-service"' "${SETUP_CHECKER_FILE}")"
  [ "${val}" = "2" ]
}

@test "version-script supports system type" {
  _source_lib
  version-script svc system 3
  val="$(jq -r '.version.system."svc"' "${SETUP_CHECKER_FILE}")"
  [ "${val}" = "3" ]
}

@test "version-script supports privileged type" {
  _source_lib
  version-script svc privileged 5
  val="$(jq -r '.version.privileged."svc"' "${SETUP_CHECKER_FILE}")"
  [ "${val}" = "5" ]
}

@test "version-script isolates services by name" {
  _source_lib
  version-script svc-a user 1
  version-script svc-b user 1
  run version-script svc-a user 1
  [ "${status}" -eq 1 ]
  run version-script svc-b user 1
  [ "${status}" -eq 1 ]
}
