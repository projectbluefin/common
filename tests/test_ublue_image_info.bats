#!/usr/bin/env bats

SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/bin/ublue-image-info.sh"
IMAGE_RESOLVE_SCRIPT="${BATS_TEST_DIRNAME}/../system_files/shared/usr/libexec/ublue-image-resolve"
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

write_rpm_ostree_mock() {
    local body="$1"

    write_mock "rpm-ostree" "#!/usr/bin/bash
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

write_bootc_mock() {
    local ref="$1"

    printf '{"status":{"booted":{"image":{"image":{"image":"%s"}}}}}\n' "${ref}" \
        > "${WORKDIR}/bootc-status.json"
    write_mock "bootc" "#!/usr/bin/bash
cat '${WORKDIR}/bootc-status.json'"
}

run_script() {
    local image_info_file="$1"
    local path_value="$2"

    run env IMAGE_INFO_FILE="${image_info_file}" IMAGE_RESOLVE="${IMAGE_RESOLVE_SCRIPT}" \
        PATH="${path_value}" /usr/bin/bash "${SCRIPT_UNDER_TEST}"
}

@test "ublue-image-info: prints image name, tag, and locked status with fixture data" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'
    write_image_info_fixture "bluefin" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin:latest 🔐" ]
}

@test "ublue-image-info: shows unlocked status when rpm-ostree output lacks signed marker" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment"'
    write_image_info_fixture "bluefin" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [ "${output}" = $'bluefin:latest \033[5m🔓\033[0m' ]
}

@test "ublue-image-info: handles missing image-info.json without failing" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'

    run_script "${WORKDIR}/missing-image-info.json" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [ "${output}" = " 🔐" ]
}

@test "ublue-image-info: handles missing jq without failing" {
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'
    write_image_info_fixture "bluefin" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}"

    [ "${status}" -eq 0 ]
    [ "${output}" = " 🔐" ]
}

@test "ublue-image-info: live bootc tag wins over stale image-info.json" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'
    write_image_info_fixture "bluefin" "latest"
    write_bootc_mock "ghcr.io/projectbluefin/bluefin-lts:stable"

    run_script "${FIXTURE}" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin-lts:stable 🔐" ]
}
