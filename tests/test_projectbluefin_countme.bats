#!/usr/bin/env bats
# /usr/libexec/projectbluefin-countme: scope, stream, daily limit, retry.

SCRIPT="${BATS_TEST_DIRNAME}/../system_files/shared/usr/libexec/projectbluefin-countme"

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export STATE_DIRECTORY="${TEST_TMPDIR}/state"
    export IMAGE_INFO="${TEST_TMPDIR}/image-info.json"
    export MOCK_BIN="${TEST_TMPDIR}/bin"
    mkdir -p "${STATE_DIRECTORY}" "${MOCK_BIN}"

    # curl records its arguments; CURL_EXIT simulates a failed send.
    cat << 'EOF' > "${MOCK_BIN}/curl"
#!/usr/bin/env bash
echo "$@" >> "${TEST_TMPDIR}/curl.log"
exit "${CURL_EXIT:-0}"
EOF
    # bootc prints BOOTED_REF as the booted image, or fails when it is unset.
    cat << 'EOF' > "${MOCK_BIN}/bootc"
#!/usr/bin/env bash
[[ -n "${BOOTED_REF:-}" ]] || exit 1
printf '{"status":{"booted":{"image":{"image":{"image":"%s"}}}}}\n' "${BOOTED_REF}"
EOF
    chmod +x "${MOCK_BIN}/curl" "${MOCK_BIN}/bootc"
    export PATH="${MOCK_BIN}:${PATH}"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

image_info() {
    printf '{"image-name":"%s","image-flavor":"%s","image-tag":"latest"}\n' "$1" "$2" > "${IMAGE_INFO}"
}

sent_image() {
    grep -o '"image":"[^"]*"' "${TEST_TMPDIR}/curl.log"
}

@test "Dakota reports image, flavor, and the booted stream" {
    image_info dakota-nvidia nvidia
    BOOTED_REF=ghcr.io/projectbluefin/dakota-nvidia:testing run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ "$(sent_image)" = '"image":"dakota-nvidia/nvidia:testing"' ]
    grep -q '/v1/ping' "${TEST_TMPDIR}/curl.log"
    [ -e "${STATE_DIRECTORY}/last" ]
}

@test "Utah is counted; a digest-pinned ref keeps its stream" {
    image_info utah gaming
    BOOTED_REF='ghcr.io/projectbluefin/utah-gaming:stable@sha256:abc' run "${SCRIPT}"
    [ "$(sent_image)" = '"image":"utah/gaming:stable"' ]
}

@test "a tag that is not a stream is reported as unknown" {
    image_info dakota main
    BOOTED_REF=ghcr.io/projectbluefin/dakota:latest run "${SCRIPT}"
    [ "$(sent_image)" = '"image":"dakota/main:unknown"' ]
}

@test "Bluefin Classic and LTS never contact the service" {
    for name in bluefin bluefin-lts; do
        image_info "$name" main
        BOOTED_REF="ghcr.io/ublue-os/${name}:stable" run "${SCRIPT}"
        [ "$status" -eq 0 ]
    done
    [ ! -e "${TEST_TMPDIR}/curl.log" ]
    [ ! -e "${STATE_DIRECTORY}/last" ]
}

@test "no booted bootc image (live ISO, installer) sends nothing" {
    image_info dakota main
    run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ ! -e "${TEST_TMPDIR}/curl.log" ]
}

@test "at most one report per 24 hours" {
    image_info dakota main
    touch -d '2 hours ago' "${STATE_DIRECTORY}/last"
    BOOTED_REF=ghcr.io/projectbluefin/dakota:stable run "${SCRIPT}"
    [ ! -e "${TEST_TMPDIR}/curl.log" ]

    touch -d '25 hours ago' "${STATE_DIRECTORY}/last"
    BOOTED_REF=ghcr.io/projectbluefin/dakota:stable run "${SCRIPT}"
    [ -e "${TEST_TMPDIR}/curl.log" ]
}

@test "a failed send exits 0 and is retried on the next run" {
    image_info dakota main
    CURL_EXIT=22 BOOTED_REF=ghcr.io/projectbluefin/dakota:stable run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ ! -e "${STATE_DIRECTORY}/last" ]
}
