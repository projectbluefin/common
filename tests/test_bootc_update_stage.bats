#!/usr/bin/env bats
# Regression tests for projectbluefin/common#1417: the privileged
# bootc-update-stage helper treated a composefs "already up to date" refusal
# as a failure. On composefs (e.g. Dakota) `bootc upgrade` exits non-zero when
# the newest image is already booted or staged; the helper must treat only
# that refusal as success and keep any other failure's exit code.
#
# The helper invokes bootc by absolute path (/usr/bin/bootc) so the tests
# redirect that path into a sandbox stub, mirroring
# tests/test_clean_system_bootc.bats, and run the helper with a self-contained
# PATH so no host bootc can leak in.

STAGE_SCRIPT="${BATS_TEST_DIRNAME}/../system_files/shared/usr/libexec/bootc-update-stage"
WORKDIR=""

_setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"
    : > "${WORKDIR}/calls.log"
    # Redirect the helper's absolute /usr/bin/bootc into the sandbox stub.
    sed "s#/usr/bin/bootc#${WORKDIR}/bin/bootc#g" "${STAGE_SCRIPT}" \
        > "${WORKDIR}/stage.sh"
    chmod +x "${WORKDIR}/stage.sh"
    # The helper runs under `#!/usr/bin/env bash`; keep the sandbox
    # self-contained by symlinking only the tools it needs (bootc itself is
    # reached by the redirected absolute path, so no host bootc can leak in).
    for tool in bash cat grep mktemp rm tee; do
        ln -s "$(command -v ${tool})" "${WORKDIR}/bin/${tool}"
    done
}

# Install a mock bootc. Plain `upgrade` prints MOCK_BOOTC_MSG (if set) to
# stderr and exits MOCK_BOOTC_EXIT. Any other invocation behaves like current
# bootc after a pull (`No changes in: …`, exit 0), so a helper that classified
# the failure by re-running bootc would misreport it.
_install_mock_bootc() {
    cat > "${WORKDIR}/bin/bootc" <<'MOCK'
#!/usr/bin/bash
printf '%s\n' "$*" >> "${STAGE_CALLS}"
if [ "$*" = "upgrade" ]; then
    [ -n "${MOCK_BOOTC_MSG:-}" ] && printf '%s\n' "${MOCK_BOOTC_MSG}" >&2
    exit "${MOCK_BOOTC_EXIT}"
fi
echo "No changes in: mock"
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/bootc"
}

_run_stage() {
    run env STAGE_CALLS="${WORKDIR}/calls.log" \
        MOCK_BOOTC_EXIT="$1" MOCK_BOOTC_MSG="${2:-}" \
        PATH="${WORKDIR}/bin" "${WORKDIR}/stage.sh"
    # The helper classifies the one real run; bootc is never invoked twice.
    [ "$(cat "${WORKDIR}/calls.log")" = "upgrade" ]
}

setup() {
    _setup
    _install_mock_bootc
}

teardown() {
    rm -rf "${WORKDIR}"
}

# The composefs refusal, for an already-booted target (the #1417 headline case).
UP_TO_DATE_BOOTED='error: Upgrading composefs: Performing Upgrade Operation: Target image has the same fs-verity digest as the existing Some(Booted) deployment.'

# The same refusal when the newest image is already staged.
UP_TO_DATE_STAGED='error: Upgrading composefs: Performing Upgrade Operation: Target image has the same fs-verity digest as the existing Some(Staged) deployment.'

# A real failure that must still be reported, not swallowed.
REAL_ERROR='error: failed to pull and update: connection refused'

@test "bootc-update-stage: already-booted composefs refusal exits 0" {
    _run_stage 1 "${UP_TO_DATE_BOOTED}"
    [ "${status}" -eq 0 ]
    grep -qFx "System image is already up to date." <<<"${output}"
}

@test "bootc-update-stage: already-staged composefs refusal exits 0" {
    _run_stage 1 "${UP_TO_DATE_STAGED}"
    [ "${status}" -eq 0 ]
    grep -qFx "System image is already up to date." <<<"${output}"
}

@test "bootc-update-stage: a different error preserves its exit code and output" {
    # A distinctive code (not 0/1) proves the helper forwards bootc's real
    # exit status instead of collapsing every failure to `exit 1`.
    _run_stage 42 "${REAL_ERROR}"
    [ "${status}" -eq 42 ]
    grep -qFx "${REAL_ERROR}" <<<"${output}"
}

@test "bootc-update-stage: a successful update exits 0" {
    _run_stage 0
    [ "${status}" -eq 0 ]
}
