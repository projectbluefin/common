#!/usr/bin/env bats

SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/bin/ublue-image-info.sh"
WORKDIR=""
MOCKDIR=""
FIXTURE=""

setup() {
    WORKDIR="${BATS_TEST_DIRNAME}/.test_ublue_image_info.$$.$RANDOM"
    rm -rf "${WORKDIR}"
    MOCKDIR="${WORKDIR}/bin"
    FIXTURE="${WORKDIR}/image-info.json"

    mkdir -p "${MOCKDIR}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

write_mock() {
    local name="$1"
    local body="$2"

    printf '%s\n' "${body}" > "${MOCKDIR}/${name}"
    chmod +x "${MOCKDIR}/${name}"
}

write_jq_mock() {
    write_mock "jq" '#!/usr/bin/bash
/usr/bin/jq "$@"'
}

write_bootc_mock() {
    local body="$1"

    write_mock "bootc" "#!/usr/bin/bash
${body}"
}

write_image_info_fixture() {
    local image_name="$1"
    local image_tag="$2"

    cat > "${FIXTURE}" <<EOF
{
  "image-name": "${image_name}",
  "image-tag": "${image_tag}"
}
EOF
}

run_script() {
    local image_info_file="$1"
    local path_value="$2"
    local booted_image_file="${3:-${WORKDIR}/missing-booted-image}"

    run env IMAGE_INFO_FILE="${image_info_file}" BOOTED_IMAGE_FILE="${booted_image_file}" PATH="${path_value}" /usr/bin/bash "${SCRIPT_UNDER_TEST}"
}

@test "ublue-image-info: prints image name and tag with fixture data" {
    write_jq_mock
    write_bootc_mock 'exit 1'
    write_image_info_fixture "bluefin" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin:latest" ]
}

@test "ublue-image-info: prefers tag from bootc status when available" {
    write_jq_mock
    write_bootc_mock 'echo "{\"status\":{\"booted\":{\"image\":{\"image\":{\"image\":\"ghcr.io/projectbluefin/dakota:testing\"}}}}}"'
    write_image_info_fixture "dakota" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "dakota:testing" ]
}

@test "ublue-image-info: falls back to BOOTED_IMAGE_FILE when bootc status is unavailable" {
    local booted_file="${WORKDIR}/booted-image"
    write_jq_mock
    write_bootc_mock 'exit 1'
    write_image_info_fixture "dakota-nvidia-gaming" "latest"
    printf 'ghcr.io/projectbluefin/dakota-nvidia-gaming:testing\n' > "${booted_file}"

    run_script "${FIXTURE}" "${MOCKDIR}" "${booted_file}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "dakota-nvidia-gaming:testing" ]
}

@test "ublue-image-info: handles missing image-info.json without failing" {
    write_jq_mock
    write_bootc_mock 'exit 1'

    run_script "${WORKDIR}/missing-image-info.json" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${WORKDIR}/missing-image-info.json: No such file or directory"* ]]
}

@test "ublue-image-info: handles missing jq without failing" {
    write_bootc_mock 'exit 1'
    write_image_info_fixture "bluefin" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"jq: command not found"* ]]
}
