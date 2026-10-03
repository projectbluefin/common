#!/usr/bin/env bats
# Tests for the setup-docker recipe in system.just
#
# Strategy: extract the bash body from setup-docker, inject it into a
# script, and run it against mocked brew / dockerd-rootless-setuptool.sh / gum.

SYSTEM_JUST="${BATS_TEST_DIRNAME}/../system_files/bluefin/usr/share/ublue-os/just/system.just"
WORKDIR=""
MOCKDIR=""
COMMAND_LOG=""
SCRIPT=""

_extract_script() {
    local recipe="$1" out_file="$2"
    awk -v recipe="$recipe" '
        $0 ~ ("^" recipe "([[:space:]].*)?:$") { in_recipe=1; next }
        in_recipe && /^    #!\/usr\/bin\/env bash/ { found=1; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^    /, ""); print }
    ' "${SYSTEM_JUST}" > "${out_file}"
    # Guard against a recipe rename silently producing an empty test subject.
    [ -s "${out_file}" ]
}

_write_mock() {
    local name="$1"
    cat > "${MOCKDIR}/${name}"
    chmod +x "${MOCKDIR}/${name}"
}

setup() {
    WORKDIR="${BATS_TEST_DIRNAME}/.test-setup-docker-${BATS_TEST_NUMBER}-$$"
    rm -rf "${WORKDIR}"
    mkdir -p "${WORKDIR}"

    MOCKDIR="${WORKDIR}/bin"
    COMMAND_LOG="${WORKDIR}/commands.log"
    mkdir -p "${MOCKDIR}"
    : > "${COMMAND_LOG}"

    SCRIPT="${WORKDIR}/setup-docker.sh"
    _extract_script "setup-docker" "${SCRIPT}"
    chmod +x "${SCRIPT}"

    _write_mock "brew" <<'MOCK'
#!/bin/bash
echo "brew $*" >> "${COMMAND_LOG}"
MOCK

    _write_mock "dockerd-rootless-setuptool.sh" <<'MOCK'
#!/bin/bash
echo "rootless-setuptool $*" >> "${COMMAND_LOG}"
MOCK

    _write_mock "gum" <<'MOCK'
#!/bin/bash
if [[ "$1" == "confirm" ]]; then
    echo "gum confirm" >> "${COMMAND_LOG}"
    [[ "${MOCK_GUM_CONFIRM:-1}" == "1" ]] && exit 0 || exit 1
fi
MOCK

    chmod -R a+rwX "${WORKDIR}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

_run() {
    # Prepend only the mock dir plus the coreutils the script calls; do not
    # carry the real PATH, or a machine with Homebrew would run a real
    # `brew install` in the "brew not installed" case.
    run env \
        PATH="${MOCKDIR}:/usr/bin:/bin" \
        COMMAND_LOG="${COMMAND_LOG}" \
        MOCK_GUM_CONFIRM="${MOCK_GUM_CONFIRM:-1}" \
        BLUEFIN_DOCKER_SOCKET="${BLUEFIN_DOCKER_SOCKET:-${WORKDIR}/absent-docker.sock}" \
        bash "${SCRIPT}"
}

@test "setup-docker: installs docker, rootlesskit, slirp4netns then runs rootless setup" {
    _run
    [ "${status}" -eq 0 ]
    grep -qF "brew install docker docker-engine rootlesskit slirp4netns" "${COMMAND_LOG}"
    grep -qF "rootless-setuptool install" "${COMMAND_LOG}"
}

@test "setup-docker: rootless setup runs after brew install" {
    _run
    local brew_line rootless_line
    brew_line=$(grep -n "brew install" "${COMMAND_LOG}" | head -1 | cut -d: -f1)
    rootless_line=$(grep -n "rootless-setuptool" "${COMMAND_LOG}" | head -1 | cut -d: -f1)
    [ "${brew_line}" -lt "${rootless_line}" ]
}

@test "setup-docker: exits cleanly when confirm is declined" {
    MOCK_GUM_CONFIRM=0 _run
    [ "${status}" -eq 0 ]
    ! grep -qF "brew install" "${COMMAND_LOG}"
    ! grep -qF "rootless-setuptool" "${COMMAND_LOG}"
}

@test "setup-docker: errors out when brew is not installed" {
    rm -f "${MOCKDIR}/brew"
    _run
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Homebrew is required"* ]]
    ! grep -qF "brew install" "${COMMAND_LOG}"
}

@test "setup-docker: aborts before prompting when a rootful docker socket is writable" {
    local sock="${WORKDIR}/docker.sock"
    : > "${sock}"
    chmod 666 "${sock}"
    BLUEFIN_DOCKER_SOCKET="${sock}" _run
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"rootful Docker daemon is running"* ]]
    ! grep -qF "gum confirm" "${COMMAND_LOG}"
    ! grep -qF "brew install" "${COMMAND_LOG}"
    ! grep -qF "rootless-setuptool" "${COMMAND_LOG}"
}
