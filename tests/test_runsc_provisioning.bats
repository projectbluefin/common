#!/usr/bin/env bats
# Deterministic contract tests for the Common-owned shared runsc provisioner.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
HELPER="${SCRIPT_DIR}/../system_files/shared/usr/libexec/bluefin-runsc"
RUNSC_VERSION="release-20260817.0"

setup() {
    TEST_ROOT="${SCRIPT_DIR}/.bats-sandbox/runsc-provisioning.${BATS_TEST_NUMBER:-0}.$$"
    STUB_BIN="${TEST_ROOT}/stub-bin"
    PATCHED_HELPER="${TEST_ROOT}/bluefin-runsc"
    mkdir -p "${STUB_BIN}" "${TEST_ROOT}/archive/gvisor-bin" "${TEST_ROOT}/bin"

    printf '#!/usr/bin/env bash\n' > "${TEST_ROOT}/archive/runsc"
    printf 'sandbox payload\n' > "${TEST_ROOT}/archive/gvisor-bin/runsc-sandbox"
    printf 'shim payload\n' > "${TEST_ROOT}/archive/containerd-shim-runsc-v1"
    chmod +x "${TEST_ROOT}/archive/runsc" "${TEST_ROOT}/archive/gvisor-bin/runsc-sandbox"
    tar -cjf "${TEST_ROOT}/gvisor.tar.bz2" \
        -C "${TEST_ROOT}/archive" runsc gvisor-bin containerd-shim-runsc-v1
    VALID_SHA="$(sha256sum "${TEST_ROOT}/gvisor.tar.bz2" | awk '{print $1}')"

    cat > "${STUB_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${CURL_LOG}"
destination=""
while (($#)); do
    case "$1" in
        -o) destination="$2"; shift 2 ;;
        --output) destination="$2"; shift 2 ;;
        *) shift ;;
    esac
done
if [[ "$(cat "${CURL_MODE_FILE}" 2>/dev/null || true)" == corrupt ]]; then
    printf 'corrupt archive\n' > "${destination}"
else
    cp "${FIXTURE_ARCHIVE}" "${destination}"
fi
EOF
    chmod +x "${STUB_BIN}/curl"

    export PATH="${STUB_BIN}:${PATH}"
    export CURL_LOG="${TEST_ROOT}/curl.log"
    export CURL_MODE_FILE="${TEST_ROOT}/curl-mode"
    export FIXTURE_ARCHIVE="${TEST_ROOT}/gvisor.tar.bz2"
    : > "${CURL_LOG}"
}

teardown() {
    rm -f "${PATCHED_HELPER}"
    rm -rf "${TEST_ROOT}"
}

patch_helper() {
    sed \
        -e "s|/usr/local/libexec/bluefin-runsc|${TEST_ROOT}/usr/local/libexec/bluefin-runsc|g" \
        -e "s|/usr/local/bin/runsc|${TEST_ROOT}/usr/local/bin/runsc|g" \
        -e "s|ae345a8c1466586b3a163fb534301913da663a97b8ed446bc711b2e1963a32c5|${VALID_SHA}|g" \
        -e "s|a3c2443e9564dbf500893e66fd2463be3b79fe42f66825971c44dc1624d454b2|${VALID_SHA}|g" \
        "${HELPER}" > "${PATCHED_HELPER}"
    chmod +x "${PATCHED_HELPER}"
}

stub_uname() {
    local architecture="$1"
    cat > "${STUB_BIN}/uname" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-m" ]]; then
    printf '%s\\n' "${architecture}"
else
    /usr/bin/uname "\$@"
fi
EOF
    chmod +x "${STUB_BIN}/uname"
}

@test "runsc helper installs the pinned payload and discoverable link" {
    [[ -x "${HELPER}" ]]
    patch_helper

    run bash "${PATCHED_HELPER}" install

    [ "${status}" -eq 0 ]
    release_dirs=("${TEST_ROOT}/usr/local/libexec/bluefin-runsc/releases/${RUNSC_VERSION}-"*)
    [ "${#release_dirs[@]}" -eq 1 ]
    [ -x "${release_dirs[0]}/runsc" ]
    [ -x "${release_dirs[0]}/gvisor-bin/runsc-sandbox" ]
    [ -f "${TEST_ROOT}/usr/local/libexec/bluefin-runsc/.bluefin-owned" ]
    [ "$(readlink "${TEST_ROOT}/usr/local/bin/runsc")" = \
        "${release_dirs[0]}/runsc" ]
    grep -Fq 'gvisor-x86_64.tar.bz2' "${CURL_LOG}"
}

@test "runsc helper rejects unsupported architecture before network access" {
    [[ -x "${HELPER}" ]]
    patch_helper
    stub_uname riscv64

    run bash "${PATCHED_HELPER}" install

    [ "${status}" -ne 0 ]
    [ ! -s "${CURL_LOG}" ]
}

@test "runsc helper maps arm64 hosts to the upstream aarch64 asset" {
    [[ -x "${HELPER}" ]]
    patch_helper
    stub_uname arm64

    run bash "${PATCHED_HELPER}" install

    [ "${status}" -eq 0 ]
    grep -Fq 'gvisor-aarch64.tar.bz2' "${CURL_LOG}"
}

@test "runsc helper verifies the archive before its first tar read" {
    [[ -x "${HELPER}" ]]
    patch_helper
    printf 'corrupt\n' > "${CURL_MODE_FILE}"
    cat > "${STUB_BIN}/tar" <<'EOF'
#!/usr/bin/env bash
printf 'tar was called\n' > "${TAR_LOG}"
exit 99
EOF
    chmod +x "${STUB_BIN}/tar"
    export TAR_LOG="${TEST_ROOT}/tar.log"

    run bash "${PATCHED_HELPER}" install

    [ "${status}" -ne 0 ]
    [ ! -e "${TAR_LOG}" ]
}

@test "runsc helper rejects unexpected archive members" {
    [[ -x "${HELPER}" ]]
    printf 'unexpected payload\n' > "${TEST_ROOT}/archive/unexpected"
    tar -cjf "${FIXTURE_ARCHIVE}" \
        -C "${TEST_ROOT}/archive" runsc gvisor-bin containerd-shim-runsc-v1 unexpected
    VALID_SHA="$(sha256sum "${FIXTURE_ARCHIVE}" | awk '{print $1}')"
    patch_helper

    run bash "${PATCHED_HELPER}" install

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"unexpected member"* ]]
    [ ! -e "${TEST_ROOT}/usr/local/bin/runsc" ]
}

@test "runsc helper install is idempotent after the pinned release is active" {
    [[ -x "${HELPER}" ]]
    patch_helper

    run bash "${PATCHED_HELPER}" install
    [ "${status}" -eq 0 ]
    first_curl_count="$(wc -l < "${CURL_LOG}")"

    run bash "${PATCHED_HELPER}" install

    [ "${status}" -eq 0 ]
    [ "$(wc -l < "${CURL_LOG}")" -eq "${first_curl_count}" ]
}

@test "runsc helper leaves the active release unchanged after a failed update" {
    [[ -x "${HELPER}" ]]
    patch_helper
    run "${PATCHED_HELPER}" install
    [ "${status}" -eq 0 ]
    active_link="$(readlink "${TEST_ROOT}/usr/local/bin/runsc")"
    rm -rf "$(dirname "${active_link}")/gvisor-bin"
    printf 'corrupt\n' > "${CURL_MODE_FILE}"

    run bash "${PATCHED_HELPER}" update

    [ "${status}" -ne 0 ]
    [ "$(readlink "${TEST_ROOT}/usr/local/bin/runsc")" = "${active_link}" ]
}

@test "runsc helper removes only its owned installation" {
    [[ -x "${HELPER}" ]]
    patch_helper
    run bash "${PATCHED_HELPER}" install
    [ "${status}" -eq 0 ]

    run bash "${PATCHED_HELPER}" remove

    [ "${status}" -eq 0 ]
    [ ! -e "${TEST_ROOT}/usr/local/bin/runsc" ]
    [ ! -e "${TEST_ROOT}/usr/local/libexec/bluefin-runsc" ]
}

@test "runsc helper refuses to remove a foreign runsc link" {
    [[ -x "${HELPER}" ]]
    patch_helper
    mkdir -p "${TEST_ROOT}/usr/local/bin"
    printf '#!/usr/bin/env bash\n' > "${TEST_ROOT}/foreign-runsc"
    chmod +x "${TEST_ROOT}/foreign-runsc"
    ln -s "${TEST_ROOT}/foreign-runsc" "${TEST_ROOT}/usr/local/bin/runsc"
    mkdir -p "${TEST_ROOT}/usr/local/libexec/bluefin-runsc"
    printf 'owned data\n' > "${TEST_ROOT}/usr/local/libexec/bluefin-runsc/keep"

    run bash "${PATCHED_HELPER}" remove

    [ "${status}" -ne 0 ]
    [ -L "${TEST_ROOT}/usr/local/bin/runsc" ]
    [ -e "${TEST_ROOT}/usr/local/libexec/bluefin-runsc/keep" ]
}

@test "runsc helper refuses an unowned root and preserves foreign children" {

    [[ -x "${HELPER}" ]]

    patch_helper
    mkdir -p "${TEST_ROOT}/usr/local/libexec/bluefin-runsc"
    printf 'foreign data\n' > "${TEST_ROOT}/usr/local/libexec/bluefin-runsc/foreign"

    run "${PATCHED_HELPER}" remove

    [ "${status}" -ne 0 ]
    [ -e "${TEST_ROOT}/usr/local/libexec/bluefin-runsc/foreign" ]

    run bash "${PATCHED_HELPER}" install

    [ "${status}" -ne 0 ]
    [ ! -s "${CURL_LOG}" ]
    [ -e "${TEST_ROOT}/usr/local/libexec/bluefin-runsc/foreign" ]
}

@test "runsc helper refuses a symlinked root or release directory" {

    [[ -x "${HELPER}" ]]

    patch_helper
    mkdir -p "${TEST_ROOT}/usr/local/libexec"
    mkdir -p "${TEST_ROOT}/foreign"
    ln -s "${TEST_ROOT}/foreign" "${TEST_ROOT}/usr/local/libexec/bluefin-runsc"

    run "${PATCHED_HELPER}" remove

    [ "${status}" -ne 0 ]
    [ -d "${TEST_ROOT}/foreign" ]

    rm -f "${TEST_ROOT}/usr/local/libexec/bluefin-runsc"
    mkdir -p "${TEST_ROOT}/usr/local/libexec/bluefin-runsc"
    printf 'bluefin-runsc ownership marker v1\n' > \
        "${TEST_ROOT}/usr/local/libexec/bluefin-runsc/.bluefin-owned"
    ln -s "${TEST_ROOT}/foreign" \
        "${TEST_ROOT}/usr/local/libexec/bluefin-runsc/releases"

    run bash "${PATCHED_HELPER}" install

    [ "${status}" -ne 0 ]
    [ -d "${TEST_ROOT}/foreign" ]
}

@test "runsc helper cleans a staged release after publication failure" {

    [[ -x "${HELPER}" ]]

    patch_helper
    run "${PATCHED_HELPER}" install
    [ "${status}" -eq 0 ]
    active_link="$(readlink "${TEST_ROOT}/usr/local/bin/runsc")"
    release_dirs=("${TEST_ROOT}/usr/local/libexec/bluefin-runsc/releases/"*)

    cat > "${STUB_BIN}/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${!#}" == "${FAIL_MV_TARGET}" ]]; then
    exit 23
fi
exec /usr/bin/mv "$@"
EOF
    chmod +x "${STUB_BIN}/mv"
    sed 's/release-20260817.0/release-20260818.0/g' \
        "${PATCHED_HELPER}" > "${TEST_ROOT}/bluefin-runsc-update"
    chmod +x "${TEST_ROOT}/bluefin-runsc-update"
    export FAIL_MV_TARGET="${TEST_ROOT}/usr/local/bin/runsc"

    run bash "${TEST_ROOT}/bluefin-runsc-update" update

    [ "${status}" -ne 0 ]
    [ "$(readlink "${TEST_ROOT}/usr/local/bin/runsc")" = "${active_link}" ]
    [ -x "${active_link}" ]
    [ -d "$(dirname "${active_link}")/gvisor-bin" ]
    after_release_dirs=("${TEST_ROOT}/usr/local/libexec/bluefin-runsc/releases/"*)
    [ "${#after_release_dirs[@]}" -eq "${#release_dirs[@]}" ]
}

@test "runsc recipe and helper do not change defaults or weaken runtime isolation" {
    [[ -x "${HELPER}" ]]
    RECIPE="${SCRIPT_DIR}/../system_files/shared/usr/share/ublue-os/just/shared.just"
    [[ -f "${RECIPE}" ]]
    run grep -Eiq 'runsc action=' "${RECIPE}"
    [ "${status}" -eq 0 ]
    run grep -Eiq 'bluefin-runsc' "${RECIPE}"
    [ "${status}" -eq 0 ]
    run grep -Eiq 'runtime[[:space:]]*=' "${RECIPE}"
    [ "${status}" -ne 0 ]
    run grep -Eiq 'ignore-cgroups|network=host|curl[^\n]*PATH' "${HELPER}" "${RECIPE}"
    [ "${status}" -ne 0 ]
}
