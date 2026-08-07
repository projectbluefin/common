#!/usr/bin/env bats
# Tests for system_files/shared/usr/libexec/ublue-image-resolve
#
# The resolver prefers `bootc status --json` (live system) over the build-time
# image-info.json, which goes stale once a user rebases. Tests mock `bootc` and
# `jq` onto PATH so no real system state is touched.
#
# Run: bats tests/test_ublue_image_resolve.bats

RESOLVER="${BATS_TEST_DIRNAME}/../system_files/shared/usr/libexec/ublue-image-resolve"

WORKDIR=""
MOCKDIR=""
FIXTURE=""

setup() {
    WORKDIR="${BATS_TEST_DIRNAME}/.test_ublue_image_resolve.$$.$RANDOM"
    rm -rf "${WORKDIR}"
    MOCKDIR="${WORKDIR}/bin"
    FIXTURE="${WORKDIR}/image-info.json"

    mkdir -p "${MOCKDIR}"

    # jq is a passthrough to the real binary; tests that need jq absent simply
    # omit it from PATH.
    printf '#!/usr/bin/bash\n/usr/bin/jq "$@"\n' > "${MOCKDIR}/jq"
    chmod +x "${MOCKDIR}/jq"
}

teardown() {
    rm -rf "${WORKDIR}"
}

write_baked_info() {
    cat > "${FIXTURE}" <<EOF
{
  "image-name": "$1",
  "image-tag": "$2",
  "image-ref": "$3"
}
EOF
}

# Mock bootc returning a booted image with the given full ref.
write_bootc_mock() {
    local ref="$1"

    printf '{"status":{"booted":{"image":{"image":{"image":"%s","transport":"registry"}}}}}\n' \
        "${ref}" > "${WORKDIR}/bootc-status.json"
    printf '#!/usr/bin/bash\n/usr/bin/cat %s\n' "${WORKDIR}/bootc-status.json" > "${MOCKDIR}/bootc"
    chmod +x "${MOCKDIR}/bootc"
}

# Mock bootc emitting arbitrary output with an arbitrary exit code.
write_bootc_raw_mock() {
    local body="$1" rc="${2:-0}"

    printf '#!/usr/bin/bash\nprintf %%s %s\nexit %s\n' "'${body}'" "${rc}" > "${MOCKDIR}/bootc"
    chmod +x "${MOCKDIR}/bootc"
}

run_resolver() {
    run env IMAGE_INFO_FILE="${FIXTURE}" PATH="${MOCKDIR}" /usr/bin/bash "${RESOLVER}" "$@"
}

# ---------------------------------------------------------------------------
# bootc present — live state wins
# ---------------------------------------------------------------------------

@test "resolve: live bootc tag beats a stale image-info.json" {
    write_baked_info "bluefin" "latest" "ostree-image-signed:docker://ghcr.io/projectbluefin/bluefin:latest"
    write_bootc_mock "ghcr.io/projectbluefin/bluefin-lts:stable"

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "stable" ]
}

@test "resolve: live bootc image name beats a stale image-info.json" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"
    write_bootc_mock "ghcr.io/projectbluefin/bluefin-lts:stable"

    run_resolver image-name

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin-lts" ]
}

@test "resolve: image-path strips the tag from the live ref" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin"
    write_bootc_mock "ghcr.io/projectbluefin/bluefin-lts:stable"

    run_resolver image-path

    [ "${status}" -eq 0 ]
    [ "${output}" = "ghcr.io/projectbluefin/bluefin-lts" ]
}

@test "resolve: image-path strips both tag and digest from the live ref" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin"
    write_bootc_mock "ghcr.io/projectbluefin/bluefin-lts:stable@sha256:0123456789abcdef"

    run_resolver image-path

    [ "${status}" -eq 0 ]
    [ "${output}" = "ghcr.io/projectbluefin/bluefin-lts" ]
}

@test "resolve: image-path keeps a registry port intact" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin"
    write_bootc_mock "registry.example.com:5000/projectbluefin/bluefin:testing"

    run_resolver image-path

    [ "${status}" -eq 0 ]
    [ "${output}" = "registry.example.com:5000/projectbluefin/bluefin" ]
}

@test "resolve: image-path keeps a ported registry with no tag intact" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin"
    write_bootc_mock "registry.example.com:5000/projectbluefin/bluefin"

    run_resolver image-path

    [ "${status}" -eq 0 ]
    [ "${output}" = "registry.example.com:5000/projectbluefin/bluefin" ]
}

# ---------------------------------------------------------------------------
# Ref parsing edge cases
# ---------------------------------------------------------------------------

@test "resolve: tag-and-digest ref yields the tag, not the digest" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"
    write_bootc_mock "ghcr.io/projectbluefin/bluefin-lts:stable@sha256:0123456789abcdef"

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "stable" ]
}

@test "resolve: digest-only ref falls back to the baked tag" {
    write_baked_info "bluefin" "gts" "ghcr.io/projectbluefin/bluefin:gts"
    write_bootc_mock "ghcr.io/projectbluefin/bluefin-lts@sha256:0123456789abcdef"

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "gts" ]
}

@test "resolve: digest-only ref still yields the live image name" {
    write_baked_info "bluefin" "gts" "ghcr.io/projectbluefin/bluefin:gts"
    write_bootc_mock "ghcr.io/projectbluefin/bluefin-lts@sha256:0123456789abcdef"

    run_resolver image-name

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin-lts" ]
}

@test "resolve: registry with a port does not confuse tag parsing" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"
    write_bootc_mock "registry.example.com:5000/projectbluefin/bluefin:testing"

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "testing" ]
}

@test "resolve: registry with a port does not confuse name parsing" {
    write_baked_info "dakota" "latest" "ghcr.io/projectbluefin/dakota:latest"
    write_bootc_mock "registry.example.com:5000/projectbluefin/bluefin:testing"

    run_resolver image-name

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin" ]
}

@test "resolve: ported registry with no tag falls back to the baked tag" {
    write_baked_info "bluefin" "gts" "ghcr.io/projectbluefin/bluefin:gts"
    write_bootc_mock "registry.example.com:5000/projectbluefin/bluefin"

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "gts" ]
}

# ---------------------------------------------------------------------------
# Fallback paths — bootc missing, failing, or useless
# ---------------------------------------------------------------------------

@test "resolve: bootc absent falls back to image-info.json" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "latest" ]
}

@test "resolve: bootc exiting non-zero falls back to image-info.json" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"
    write_bootc_raw_mock "error: must be run as root" 1

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "latest" ]
}

@test "resolve: empty bootc output falls back to image-info.json" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"
    write_bootc_raw_mock "" 0

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "latest" ]
}

@test "resolve: invalid bootc JSON falls back to image-info.json" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"
    write_bootc_raw_mock "not json at all" 0

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "latest" ]
}

@test "resolve: non-bootc host (booted null) falls back to image-info.json" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"
    write_bootc_raw_mock '{"status":{"booted":null}}' 0

    run_resolver image-tag

    [ "${status}" -eq 0 ]
    [ "${output}" = "latest" ]
}

@test "resolve: baked image-ref transport prefix is stripped for image-path" {
    write_baked_info "bluefin" "latest" "ostree-image-signed:docker://ghcr.io/projectbluefin/bluefin"

    run_resolver image-path

    [ "${status}" -eq 0 ]
    [ "${output}" = "ghcr.io/projectbluefin/bluefin" ]
}

@test "resolve: baked image-ref without a transport scheme is stripped for image-path" {
    write_baked_info "bluefin" "latest" "ostree-unverified-registry:ghcr.io/projectbluefin/bluefin"

    run_resolver image-path

    [ "${status}" -eq 0 ]
    [ "${output}" = "ghcr.io/projectbluefin/bluefin" ]
}

@test "resolve: baked image-ref with a tag yields a tagless image-path" {
    write_baked_info "bluefin" "latest" "ostree-image-signed:docker://ghcr.io/projectbluefin/bluefin:latest"

    run_resolver image-path

    [ "${status}" -eq 0 ]
    [ "${output}" = "ghcr.io/projectbluefin/bluefin" ]
}

# ---------------------------------------------------------------------------
# Nothing resolvable / misuse
# ---------------------------------------------------------------------------

@test "resolve: missing image-info.json and no bootc exits non-zero with no output" {
    run_resolver image-tag

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
}

@test "resolve: jq absent exits non-zero without crashing" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"
    rm -f "${MOCKDIR}/jq"

    run_resolver image-tag

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
}

@test "resolve: unknown field is rejected" {
    write_baked_info "bluefin" "latest" "ghcr.io/projectbluefin/bluefin:latest"

    run_resolver image-flavor

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"usage:"* ]]
}
