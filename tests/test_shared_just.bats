#!/usr/bin/env bats
# Tests for system_files/shared/usr/share/ublue-os/just/shared.just
#
# Covers the recipes defined there:
#   - powerwash   (destructive factory reset, double-confirmation gated)
#   - toggle-tpm2 (LUKS TPM2 auto-unlock toggle)
#   - contribute  (podman alias for the Hive contributor appliance, #1277)
#
# The powerwash and contribute recipe bodies are `#!/usr/bin/bash` shebang
# recipes with no just interpolation, so they can be extracted verbatim and
# executed against stubbed binaries (bctl/gum/sudo, podman/gh). That exercises
# the real control flow instead of grepping the recipe text.

SHARED_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/shared.just"
WORKDIR=""

# Extract a shebang recipe body from shared.just and dedent it by four spaces.
_extract_recipe() {
    awk -v name="$1" '
        $0 == name ":" { in_recipe = 1; next }
        in_recipe && $0 ~ /^[^[:space:]]/ { exit }
        in_recipe && $0 ~ /^    / { sub(/^    /, ""); print }
        in_recipe && $0 == "" { print }
    ' "${SHARED_JUST}"
}

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"
    : > "${WORKDIR}/calls.log"
    : > "${WORKDIR}/gum-answers"

    _extract_recipe powerwash > "${WORKDIR}/powerwash.sh"
    chmod +x "${WORKDIR}/powerwash.sh"

    _extract_recipe contribute > "${WORKDIR}/contribute.sh"
    chmod +x "${WORKDIR}/contribute.sh"

    # gum stub: pops one answer per invocation from GUM_ANSWERS.
    cat > "${WORKDIR}/bin/gum" <<'EOF'
#!/usr/bin/bash
printf 'gum %s\n' "$*" >> "${CALLS}"
answer="$(/usr/bin/head -n1 "${GUM_ANSWERS}")"
/usr/bin/tail -n +2 "${GUM_ANSWERS}" > "${GUM_ANSWERS}.tmp"
/bin/mv "${GUM_ANSWERS}.tmp" "${GUM_ANSWERS}"
printf '%s\n' "${answer}"
EOF

    cat > "${WORKDIR}/bin/sudo" <<'EOF'
#!/usr/bin/bash
printf 'sudo %s\n' "$*" >> "${CALLS}"
EOF

    cat > "${WORKDIR}/bin/bctl" <<'EOF'
#!/usr/bin/bash
printf 'bctl %s\n' "$*" >> "${CALLS}"
EOF

    # podman stub: succeeds by default; "--runtime=krun info" fails unless
    # KRUN_AVAILABLE=1 is set, so tests can toggle the isolation-tier path.
    cat > "${WORKDIR}/bin/podman" <<'EOF'
#!/usr/bin/bash
printf 'podman %s\n' "$*" >> "${CALLS}"
printf 'podman-env GH_TOKEN=%s\n' "${GH_TOKEN:-}" >> "${CALLS}"
if [[ "$1" == "--runtime=krun" ]]; then
    [[ "${KRUN_AVAILABLE:-0}" == 1 ]] && exit 0 || exit 1
fi
exit 0
EOF

    cat > "${WORKDIR}/bin/gh" <<'EOF'
#!/usr/bin/bash
printf 'gh %s\n' "$*" >> "${CALLS}"
if [[ "$1" == "attestation" ]]; then
    [[ "${GH_ATTEST_FAIL:-0}" == 1 ]] && { echo "stub: verification failed"; exit 1; }
    exit 0
fi
printf '%s\n' "${GH_STUB_TOKEN:-}"
EOF

    chmod +x "${WORKDIR}/bin/gum" "${WORKDIR}/bin/sudo" "${WORKDIR}/bin/bctl" "${WORKDIR}/bin/podman" "${WORKDIR}/bin/gh"
}

teardown() {
    rm -rf "${WORKDIR}"
}

_queue_answers() {
    printf '%s\n' "$@" > "${WORKDIR}/gum-answers"
}

# Run the extracted powerwash recipe. Pass "with-bctl" to keep the bctl stub on
# PATH; anything else removes it so the gum confirmation path is taken.
_run_powerwash() {
    if [ "${1:-}" != "with-bctl" ]; then
        rm -f "${WORKDIR}/bin/bctl"
    fi
    run /usr/bin/env -i \
        PATH="${WORKDIR}/bin:/usr/bin:/bin" \
        CALLS="${WORKDIR}/calls.log" \
        GUM_ANSWERS="${WORKDIR}/gum-answers" \
        /usr/bin/bash "${WORKDIR}/powerwash.sh"
}

_calls() {
    cat "${WORKDIR}/calls.log"
}

@test "shared.just: powerwash recipe body is extractable and non-empty" {
    [ -s "${WORKDIR}/powerwash.sh" ]
    run head -n1 "${WORKDIR}/powerwash.sh"
    [ "${output}" = "#!/usr/bin/bash" ]
}

@test "powerwash: two confirmations run bootc install reset via sudo" {
    _queue_answers "Yes - wipe this machine" "Yes - wipe this machine"

    _run_powerwash

    [ "${status}" -eq 0 ]
    run grep -Fqx "sudo bootc install reset --experimental" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
    # Both confirmations were prompted before any destructive call.
    [ "$(grep -c '^gum ' <<< "$(_calls)")" -eq 2 ]
}

@test "powerwash: never invokes bctl even when bctl is on PATH" {
    # bctl delegation was removed in #1083; the recipe owns the flow directly.
    _queue_answers "Yes - wipe this machine" "Yes - wipe this machine"

    _run_powerwash with-bctl

    [ "${status}" -eq 0 ]
    run grep -q "^bctl " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
    run grep -Fqx "sudo bootc install reset --experimental" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "powerwash: declining the first confirmation cancels without wiping" {
    _queue_answers "No" "Yes - wipe this machine"

    _run_powerwash

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Powerwash cancelled."* ]]
    run grep -q "^sudo " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "powerwash: declining the first confirmation asks only once" {
    _queue_answers "No" "Yes - wipe this machine"

    _run_powerwash

    [ "$(grep -c "^gum " <<< "$(_calls)")" -eq 1 ]
}

@test "powerwash: declining the second confirmation cancels without wiping" {
    _queue_answers "Yes - wipe this machine" "No"

    _run_powerwash

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Powerwash cancelled."* ]]
    run grep -q "^sudo " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "powerwash: a single confirmation is never enough — two prompts are required" {
    _queue_answers "Yes - wipe this machine" "No"

    _run_powerwash

    [ "$(grep -c "^gum " <<< "$(_calls)")" -eq 2 ]
}

@test "powerwash: an unrelated gum answer is treated as a decline" {
    _queue_answers "maybe" "Yes - wipe this machine"

    _run_powerwash

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Powerwash cancelled."* ]]
    run grep -q "^sudo " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "powerwash: empty gum output is treated as a decline" {
    _queue_answers "" "Yes - wipe this machine"

    _run_powerwash

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Powerwash cancelled."* ]]
    run grep -q "^sudo " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "powerwash: both confirmations run the experimental bootc reset" {
    _queue_answers "Yes - wipe this machine" "Yes - wipe this machine"

    _run_powerwash

    [ "${status}" -eq 0 ]
    run grep -Fq "sudo bootc install reset --experimental" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "powerwash: the reset is issued exactly once" {
    _queue_answers "Yes - wipe this machine" "Yes - wipe this machine"

    _run_powerwash

    [ "$(grep -c "^sudo " <<< "$(_calls)")" -eq 1 ]
}

@test "powerwash: both prompts warn the user before wiping" {
    _queue_answers "Yes - wipe this machine" "Yes - wipe this machine"

    _run_powerwash

    local calls
    calls="$(_calls)"
    run grep -Fq "experimental feature that will reset this device" <<< "${calls}"
    [ "${status}" -eq 0 ]
    run grep -Fq "Are you sure?" <<< "${calls}"
    [ "${status}" -eq 0 ]
}

@test "toggle-tpm2: invokes the absolute luks-tpm2-autounlock path" {
    run grep -A2 '^toggle-tpm2:' "${SHARED_JUST}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"/usr/bin/luks-tpm2-autounlock"* ]]
}

@test "shared.just: recipes are grouped under System" {
    [ "$(grep -c "^\[group('System')\]" "${SHARED_JUST}")" -eq 3 ]
}

# -- contribute (#1277) -------------------------------------------------------

_run_contribute() {
    run /usr/bin/env -i \
        PATH="${WORKDIR}/bin:/usr/bin:/bin" \
        HOME="${WORKDIR}/home" \
        CALLS="${WORKDIR}/calls.log" \
        KRUN_AVAILABLE="${KRUN_AVAILABLE:-0}" \
        GH_STUB_TOKEN="${GH_STUB_TOKEN:-}" \
        GH_ATTEST_FAIL="${GH_ATTEST_FAIL:-0}" \
        /usr/bin/bash "${WORKDIR}/contribute.sh"
}

@test "shared.just: contribute recipe body is extractable and non-empty" {
    [ -s "${WORKDIR}/contribute.sh" ]
    run head -n1 "${WORKDIR}/contribute.sh"
    [ "${output}" = "#!/usr/bin/bash" ]
}

@test "contribute: fails with a clear message when podman is absent" {
    rm -f "${WORKDIR}/bin/podman"
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"
    # PATH is limited to the stub dir so a host /usr/bin/podman (present on
    # GitHub runners) can't satisfy the check; link the two tools the recipe
    # runs before it.
    ln -s "$(command -v sha256sum)" "${WORKDIR}/bin/sha256sum"
    ln -s "$(command -v cut)" "${WORKDIR}/bin/cut"

    run /usr/bin/env -i \
        PATH="${WORKDIR}/bin" \
        HOME="${WORKDIR}/home" \
        CALLS="${WORKDIR}/calls.log" \
        /usr/bin/bash "${WORKDIR}/contribute.sh"

    [ "${status}" -eq 127 ]
    [[ "${output}" == *"podman is required"* ]]
}

@test "contribute: fails with guidance when unregistered" {
    _run_contribute

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"no Hive registration"* ]]
}

@test "contribute: warns but still runs when krun/gVisor is unavailable" {
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"
    KRUN_AVAILABLE=0

    _run_contribute

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"WARNING"*"krun/gVisor"* ]]
    # The launch line ("podman run ...") must not carry --runtime=krun; the
    # earlier preflight probe ("podman --runtime=krun info") legitimately does.
    run grep -F -- "podman run" "${WORKDIR}/calls.log"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"--runtime=krun"* ]]
}

@test "contribute: reports krun when available (KVM device stubbed absent still falls back safely)" {
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"
    KRUN_AVAILABLE=1

    _run_contribute

    [ "${status}" -eq 0 ]
    # /dev/kvm is not guaranteed readable/writable in CI, so the recipe still
    # falls back safely -- the important behavior is that it never hard-fails.
    [[ "${output}" == *"krun"*"KVM"* || "${output}" == *"WARNING"* ]]
}

@test "contribute: always applies a memory and cpu ceiling" {
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"

    _run_contribute

    run grep -Fq -- "--memory 4g --memory-swap 4g --cpus 2" <<< "$(cat "${WORKDIR}/calls.log")"
    [ "${status}" -eq 0 ]
}

@test "contribute: runs foreground-only (no --detach flag)" {
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"

    _run_contribute

    run grep -Fq -- "--interactive --tty" <<< "$(cat "${WORKDIR}/calls.log")"
    [ "${status}" -eq 0 ]
    run grep -Eq -- "--detach\b" <<< "$(cat "${WORKDIR}/calls.log")"
    [ "${status}" -ne 0 ]
}

@test "contribute: forwards a GitHub token resolved via gh when GH_TOKEN is unset" {
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"
    GH_STUB_TOKEN="stub-token-value"

    _run_contribute

    [ "${status}" -eq 0 ]
    # Forwarded by name: the value reaches podman's environment, never its argv.
    run grep -F -- "podman run" "${WORKDIR}/calls.log"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--env GH_TOKEN "* ]]
    [[ "${output}" != *"stub-token-value"* ]]
    run grep -Fq -- "podman-env GH_TOKEN=stub-token-value" "${WORKDIR}/calls.log"
    [ "${status}" -eq 0 ]
}

@test "contribute: defaults to the projectbluefin hive hub" {
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"

    _run_contribute

    [[ "${output}" == *"hive.hivecommons.dev"* ]]
}

@test "contribute: HIVE_CONTRIBUTE_HUB overrides the default hub" {
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"

    run /usr/bin/env -i \
        PATH="${WORKDIR}/bin:/usr/bin:/bin" \
        HOME="${WORKDIR}/home" \
        CALLS="${WORKDIR}/calls.log" \
        HIVE_CONTRIBUTE_HUB="wss://example.test/api/contribute/ws" \
        /usr/bin/bash "${WORKDIR}/contribute.sh"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"wss://example.test/api/contribute/ws"* ]]
}

@test "contribute: verifies image provenance before launching with --pull=never" {
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"

    _run_contribute

    [ "${status}" -eq 0 ]
    run grep -F -- "gh attestation verify oci://ghcr.io/projectbluefin/contribute" "${WORKDIR}/calls.log"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--repo projectbluefin/contribute"* ]]
    run grep -F -- "podman run --pull=never" "${WORKDIR}/calls.log"
    [ "${status}" -eq 0 ]
}

@test "contribute: refuses to launch when provenance verification fails" {
    mkdir -p "${WORKDIR}/home/.config/hive"
    : > "${WORKDIR}/home/.config/hive/contributor.env"
    GH_ATTEST_FAIL=1

    _run_contribute

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"refusing to launch"* ]]
    run grep -F -- "podman run" "${WORKDIR}/calls.log"
    [ "${status}" -ne 0 ]
}
