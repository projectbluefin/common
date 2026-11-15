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
    # The script must never run bootc (#1198): a bootc started from this
    # unconfined service is denied mac_admin by its SELinux probe. This stub
    # leaves a marker, and teardown checks it is absent.
    cat << 'EOF' > "${MOCK_BIN}/bootc"
#!/usr/bin/env bash
touch "${TEST_TMPDIR}/bootc.called"
exit 1
EOF
    chmod +x "${MOCK_BIN}/curl" "${MOCK_BIN}/bootc"
    # No booted deployment and no snapshot unless a test creates one.
    export COUNTME_CMDLINE="${TEST_TMPDIR}/cmdline"
    export UBLUE_BOOTED_IMAGE_FILE="${TEST_TMPDIR}/booted-image"
    echo "BOOT_IMAGE=/vmlinuz root=/dev/vda2" > "${COUNTME_CMDLINE}"
    export PATH="${MOCK_BIN}:${PATH}"
}

teardown() {
    [ ! -e "${TEST_TMPDIR}/bootc.called" ]
    rm -rf "${TEST_TMPDIR}"
}

image_info() {
    printf '{"image-name":"%s","image-flavor":"%s","image-tag":"latest"}\n' "$1" "$2" > "${IMAGE_INFO}"
}

# booted REF [ORIGIN_VALUE]: fake an ostree deployment whose .origin keyfile
# names REF, reached from ostree= on the kernel command line through a symlink
# like /ostree/boot.N/<stateroot>/<csum>/<serial>.
booted() {
    local d="${TEST_TMPDIR}/deploy/abc123.0"
    mkdir -p "$d" "${TEST_TMPDIR}/boot/default/abc123"
    ln -sfn "$d" "${TEST_TMPDIR}/boot/default/abc123/0"
    printf '[origin]\ncontainer-image-reference=%s\n' "${2:-ostree-unverified-registry:$1}" \
        > "${d}.origin"
    echo "BOOT_IMAGE=/vmlinuz ostree=${TEST_TMPDIR}/boot/default/abc123/0 rw" > "${COUNTME_CMDLINE}"
}

sent_image() {
    grep -o '"image":"[^"]*"' "${TEST_TMPDIR}/curl.log"
}

@test "Dakota reports image, flavor, and the booted stream" {
    image_info dakota-nvidia nvidia
    booted ghcr.io/projectbluefin/dakota-nvidia:testing
    run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ "$(sent_image)" = '"image":"dakota-nvidia/nvidia:testing"' ]
    grep -q '/v1/ping' "${TEST_TMPDIR}/curl.log"
    [ -e "${STATE_DIRECTORY}/last" ]
}

@test "Utah is counted; a digest-pinned ref keeps its stream" {
    image_info utah gaming
    booted 'ghcr.io/projectbluefin/utah-gaming:stable@sha256:abc'
    run "${SCRIPT}"
    [ "$(sent_image)" = '"image":"utah/gaming:stable"' ]
}

@test "a tag that is not a stream is reported as unknown" {
    image_info dakota main
    booted ghcr.io/projectbluefin/dakota:next
    run "${SCRIPT}"
    [ "$(sent_image)" = '"image":"dakota/main:unknown"' ]
}

@test "latest from bootc is reported as a stream" {
    image_info dakota main
    booted ghcr.io/projectbluefin/dakota:latest
    run "${SCRIPT}"
    [ "$(sent_image)" = '"image":"dakota/main:latest"' ]
}

@test "Server (DDI) reports its image-tag stream without bootc" {
    image_info server main
    run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ "$(sent_image)" = '"image":"server/main:latest"' ]
    [ -e "${STATE_DIRECTORY}/last" ]
}

@test "Server (DDI) skips when image-tag is empty" {
    printf '{"image-name":"server","image-flavor":"main"}\n' > "${IMAGE_INFO}"
    run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ ! -e "${TEST_TMPDIR}/curl.log" ]
    [ ! -e "${STATE_DIRECTORY}/last" ]
}

@test "Server (DDI) skips when image-name is not exactly server" {
    image_info server-foo main
    run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ ! -e "${TEST_TMPDIR}/curl.log" ]
}

@test "bootc images do not use image-tag as a stream fallback" {
    # dakota with no bootc image and a baked image-tag must not count — the
    # baked tag is the compose tag, not the stream the system actually runs.
    image_info dakota main
    run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ ! -e "${TEST_TMPDIR}/curl.log" ]
}

@test "Server (DDI) reports a non-stream image-tag as unknown" {
    printf '{"image-name":"server","image-flavor":"main","image-tag":"20261007"}\n' > "${IMAGE_INFO}"
    run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ "$(sent_image)" = '"image":"server/main:unknown"' ]
}

@test "unit skips bootc hosts with empty /home but not non-ostree hosts" {
    unit="${BATS_TEST_DIRNAME}/../system_files/shared/usr/lib/systemd/system/projectbluefin-countme.service"
    grep -qx 'ConditionDirectoryNotEmpty=|/home' "$unit"
    grep -qx 'ConditionPathExists=|!/run/ostree-booted' "$unit"
    grep -qx 'ProtectHome=yes' "$unit"
}

@test "Bluefin Classic and LTS never contact the service" {
    for name in bluefin bluefin-lts; do
        image_info "$name" main
        booted ghcr.io/ublue-os/${name}:stable
    run "${SCRIPT}"
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
    booted ghcr.io/projectbluefin/dakota:stable
    run "${SCRIPT}"
    [ ! -e "${TEST_TMPDIR}/curl.log" ]

    touch -d '25 hours ago' "${STATE_DIRECTORY}/last"
    booted ghcr.io/projectbluefin/dakota:stable
    run "${SCRIPT}"
    [ -e "${TEST_TMPDIR}/curl.log" ]
}

@test "a failed send exits 0 and is retried on the next run" {
    image_info dakota main
    booted ghcr.io/projectbluefin/dakota:stable
    CURL_EXIT=22 run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ ! -e "${STATE_DIRECTORY}/last" ]
}

@test "the ref comes from the .origin file for every transport form" {
    image_info dakota main
    for form in \
        'ostree-image-signed:docker://ghcr.io/projectbluefin/dakota:stable' \
        'ostree-unverified-image:docker://ghcr.io/projectbluefin/dakota:stable' \
        'ostree-remote-registry:fedora:ghcr.io/projectbluefin/dakota:stable' \
        'ostree-remote-image:fedora:docker://ghcr.io/projectbluefin/dakota:stable' \
        'ostree-unverified-registry:ghcr.io/projectbluefin/dakota:stable'; do
        rm -f "${TEST_TMPDIR}/curl.log" "${STATE_DIRECTORY}/last"
        booted x "$form"
        run "${SCRIPT}"
        [ "$status" -eq 0 ]
        [ "$(sent_image)" = '"image":"dakota/main:stable"' ]
    done
}

@test "a registry port in the ref does not become the stream" {
    image_info dakota main
    booted localhost:5000/dakota
    run "${SCRIPT}"
    [ "$(sent_image)" = '"image":"dakota/main:unknown"' ]
}

@test "without an ostree= deployment, the boot-time snapshot supplies the ref" {
    image_info dakota main
    echo 'ghcr.io/projectbluefin/dakota:testing' > "${UBLUE_BOOTED_IMAGE_FILE}"
    run "${SCRIPT}"
    [ "$(sent_image)" = '"image":"dakota/main:testing"' ]
}

@test "the .origin file wins over the snapshot" {
    image_info dakota main
    echo 'ghcr.io/projectbluefin/dakota:testing' > "${UBLUE_BOOTED_IMAGE_FILE}"
    booted ghcr.io/projectbluefin/dakota:stable
    run "${SCRIPT}"
    [ "$(sent_image)" = '"image":"dakota/main:stable"' ]
}

@test "an ostree= path with no .origin file is treated as not booted" {
    image_info dakota main
    booted ghcr.io/projectbluefin/dakota:stable
    rm "${TEST_TMPDIR}"/deploy/abc123.0.origin
    run "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ ! -e "${TEST_TMPDIR}/curl.log" ]
}
