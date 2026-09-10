#!/usr/bin/env bats
# Tests for system_files/shared/usr/share/ublue-os/just/shared.just
#
# Covers the two recipes defined there:
#   - powerwash   (destructive factory reset, double-confirmation gated)
#   - toggle-tpm2 (LUKS TPM2 auto-unlock toggle)
#
# The powerwash recipe body is a `#!/usr/bin/bash` shebang recipe with no just
# interpolation, so it can be extracted verbatim and executed against stubbed
# bctl/gum/sudo binaries. That exercises the real control flow instead of
# grepping the recipe text.

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

    chmod +x "${WORKDIR}/bin/gum" "${WORKDIR}/bin/sudo" "${WORKDIR}/bin/bctl"
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

@test "powerwash: delegates to bctl when bctl is available" {
    _queue_answers "Yes - wipe this machine" "Yes - wipe this machine"

    _run_powerwash with-bctl

    [ "${status}" -eq 0 ]
    run grep -Fq "bctl powerwash" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "powerwash: bctl delegation skips gum prompts and sudo entirely" {
    _queue_answers "Yes - wipe this machine" "Yes - wipe this machine"

    _run_powerwash with-bctl

    run grep -q "^gum " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
    run grep -q "^sudo " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
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
    [ "$(grep -c "^\[group('System')\]" "${SHARED_JUST}")" -eq 2 ]
}
