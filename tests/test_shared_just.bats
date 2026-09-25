#!/usr/bin/env bats
# Tests for system_files/shared/usr/share/ublue-os/just/shared.just
#
# Covers the recipes defined there:
#   - powerwash                  (destructive factory reset, double-confirmation gated)
#   - toggle-tpm2                (LUKS TPM2 auto-unlock toggle)
#   - toggle-ffmpeg-thumbnailer  (opt-in toggle for the ffmpeg thumbnailer daemon)
#   - status-ffmpeg-thumbnailer  (read-only inspection of the same units)
#
# The powerwash recipe body is a `#!/usr/bin/bash` shebang recipe with no just
# interpolation, so it can be extracted verbatim and executed against stubbed
# bctl/gum/sudo binaries. That exercises the real control flow instead of
# grepping the recipe text. The same extraction approach is used for the
# thumbnailer recipes with every systemctl/podman/journalctl call stubbed.

SHARED_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/shared.just"
WORKDIR=""

# Extract a shebang recipe body from shared.just and dedent it by four spaces.
# The recipe pattern also matches parameterised recipes (`name ARG="x":`).
_extract_recipe() {
    awk -v name="$1" '
        $0 ~ ("^" name "([[:space:]].*)?:$") { in_recipe = 1; next }
        in_recipe && $0 ~ /^[^[:space:]]/ { exit }
        in_recipe && $0 ~ /^    / { sub(/^    /, ""); print }
        in_recipe && $0 == "" { print }
    ' "${SHARED_JUST}"
}

# Same extraction, but resolves the `{{ ACTION }}` just interpolation the way
# the just parser would so the body is runnable bash (see test_update_just.bats).
_extract_toggle_recipe() {
    _extract_recipe toggle-ffmpeg-thumbnailer \
        | sed 's/{{ ACTION }}/${ACTION:-prompt}/g'
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

    # systemctl stub. MOCK_UNIT_PRESENT=0 makes `systemctl --user cat` fail,
    # which is how the recipes detect that the thumbnailer is not installed.
    cat > "${WORKDIR}/bin/systemctl" <<'EOF'
#!/usr/bin/bash
printf 'systemctl %s\n' "$*" >> "${CALLS}"
[[ "${1:-}" == "--user" ]] && shift
case "${1:-}" in
    cat)
        [[ "${MOCK_UNIT_PRESENT:-1}" == "1" ]] && exit 0 || exit 1
        ;;
    is-enabled)
        [[ "${MOCK_STATE_FAIL:-0}" == "1" ]] && exit 1
        if [[ "${MOCK_MASKED:-0}" == "1" ]]; then
            printf 'masked\n'
            exit 1
        fi
        printf '%s\n' "${MOCK_ENABLED_STATE:-enabled}"
        ;;
    is-active)
        [[ "${MOCK_STATE_FAIL:-0}" == "1" ]] && exit 1
        printf '%s\n' "${MOCK_ACTIVE_STATE:-inactive}"
        ;;
    mask)
        exit "${MOCK_MASK_STATUS:-0}"
        ;;
    unmask)
        exit "${MOCK_UNMASK_STATUS:-0}"
        ;;
esac
exit 0
EOF

    cat > "${WORKDIR}/bin/podman" <<'EOF'
#!/usr/bin/bash
printf 'podman %s\n' "$*" >> "${CALLS}"
if [[ "${1:-}" == "container" && "${2:-}" == "exists" ]]; then
    exit "${MOCK_CONTAINER_EXISTS:-0}"
fi
if [[ "${1:-}" == "ps" ]]; then
    printf 'CONTAINER ID  IMAGE                                      STATUS\n'
    printf 'a1b2c3d4e5f6  jrottenberg/ffmpeg:9.0-alpine320           Up 2 hours\n'
fi
exit 0
EOF

    cat > "${WORKDIR}/bin/journalctl" <<'EOF'
#!/usr/bin/bash
printf 'journalctl %s\n' "$*" >> "${CALLS}"
if [[ "${MOCK_JOURNAL_ENTRIES:-1}" == "1" ]]; then
    printf 'Sep 25 12:00:00 host ffmpeg-thumbnailer-daemon: listening on /tmp/x.sock\n'
    exit 0
fi
exit 1
EOF

    chmod +x "${WORKDIR}/bin/gum" "${WORKDIR}/bin/sudo" "${WORKDIR}/bin/bctl" \
        "${WORKDIR}/bin/systemctl" "${WORKDIR}/bin/podman" "${WORKDIR}/bin/journalctl"

    _extract_toggle_recipe > "${WORKDIR}/toggle-thumbnailer.sh"
    chmod +x "${WORKDIR}/toggle-thumbnailer.sh"
    _extract_recipe status-ffmpeg-thumbnailer > "${WORKDIR}/status-thumbnailer.sh"
    chmod +x "${WORKDIR}/status-thumbnailer.sh"
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
    [ "$(grep -c "^\[group('System')\]" "${SHARED_JUST}")" -eq 4 ]
}

# --- ffmpeg thumbnailer toggle ------------------------------------------------

# Run an extracted thumbnailer recipe against the stubs. Every argument after
# the script name is passed to `env -i` as a KEY=VALUE assignment, so each test
# states exactly which mock behaviour it needs.
_run_thumbnailer() {
    local script="$1"
    shift
    run /usr/bin/env -i \
        PATH="${WORKDIR}/bin:/usr/bin:/bin" \
        HOME="${WORKDIR}/home" \
        CALLS="${WORKDIR}/calls.log" \
        GUM_ANSWERS="${WORKDIR}/gum-answers" \
        "$@" \
        /usr/bin/bash "${WORKDIR}/${script}"
}

_SOCKET_REL="cache/gnome-desktop-thumbnailer/gstreamer-1.0/ffmpeg-thumbnailer.sock"

_socket_path() {
    printf '%s\n' "${WORKDIR}/${_SOCKET_REL}"
}

_make_socket() {
    mkdir -p "$(dirname "$(_socket_path)")"
    python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' \
        "$(_socket_path)"
}

@test "toggle-ffmpeg-thumbnailer: recipe body is extractable and resolves ACTION" {
    [ -s "${WORKDIR}/toggle-thumbnailer.sh" ]
    run head -n1 "${WORKDIR}/toggle-thumbnailer.sh"
    [ "${output}" = "#!/usr/bin/bash" ]
    # The just-injected value must be substituted, not left as a literal
    # {{ ACTION }} expression the shell cannot evaluate.
    run grep -Fq 'ACTION_VALUE="${ACTION:-prompt}"' "${WORKDIR}/toggle-thumbnailer.sh"
    [ "${status}" -eq 0 ]
}

@test "toggle-ffmpeg-thumbnailer: disable stops and masks all three units" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=disable
    result="${output}"

    [ "${status}" -eq 0 ]
    run grep -Fqx "systemctl --user stop ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
    run grep -Fqx "systemctl --user mask ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
    [[ "${result}" == *"has been disabled"* ]]
}

@test "toggle-ffmpeg-thumbnailer: disable stops the units before masking them" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=disable

    stop_line="$(grep -n '^systemctl --user stop ' "${WORKDIR}/calls.log" | cut -d: -f1)"
    mask_line="$(grep -n '^systemctl --user mask ' "${WORKDIR}/calls.log" | cut -d: -f1)"
    [ -n "${stop_line}" ]
    [ -n "${mask_line}" ]
    [ "${stop_line}" -lt "${mask_line}" ]
}

@test "toggle-ffmpeg-thumbnailer: disable never unmasks" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=disable

    run grep -q "^systemctl --user unmask " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "toggle-ffmpeg-thumbnailer: enable unmasks, reloads, and starts daemon plus containers" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=enable
    result="${output}"

    [ "${status}" -eq 0 ]
    run grep -Fqx "systemctl --user unmask ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
    run grep -Fqx "systemctl --user daemon-reload" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
    run grep -Fqx "systemctl --user enable --now ffmpeg-thumbnailer-daemon.service" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
    run grep -Fqx "systemctl --user start ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
    [[ "${result}" == *"has been enabled"* ]]
}

@test "toggle-ffmpeg-thumbnailer: enable never masks" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=enable

    run grep -q "^systemctl --user mask " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "toggle-ffmpeg-thumbnailer: ACTION is case-insensitive" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=DISABLE

    [ "${status}" -eq 0 ]
    run grep -Fqx "systemctl --user mask ffmpeg-thumbnailer-daemon.service ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service" <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "toggle-ffmpeg-thumbnailer: ACTION=cancel changes nothing" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=cancel

    [ "${status}" -eq 0 ]
    run grep -Eq "^systemctl --user (mask|unmask|stop|start) " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "toggle-ffmpeg-thumbnailer: the prompt reports the enabled state" {
    _queue_answers "Cancel"

    _run_thumbnailer toggle-thumbnailer.sh
    result="${output}"

    [ "${status}" -eq 0 ]
    [[ "${result}" == *"currently enabled"* ]]
    run grep -q "^gum choose " <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "toggle-ffmpeg-thumbnailer: the prompt reports the masked state" {
    _queue_answers "Cancel"

    _run_thumbnailer toggle-thumbnailer.sh MOCK_MASKED=1
    result="${output}"

    [ "${status}" -eq 0 ]
    [[ "${result}" == *"currently disabled"* ]]
}

@test "toggle-ffmpeg-thumbnailer: the prompt offers Cancel and Cancel is a no-op" {
    _queue_answers "Cancel"

    _run_thumbnailer toggle-thumbnailer.sh
    result="${output}"

    run grep -Fq "Cancel" <<< "$(grep '^gum choose ' "${WORKDIR}/calls.log")"
    [ "${status}" -eq 0 ]
    [[ "${result}" == *"No changes made."* ]]
    run grep -Eq "^systemctl --user (mask|unmask|stop|start) " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "toggle-ffmpeg-thumbnailer: an unrelated prompt answer changes nothing" {
    _queue_answers "maybe"

    _run_thumbnailer toggle-thumbnailer.sh

    [ "${status}" -eq 0 ]
    run grep -Eq "^systemctl --user (mask|unmask|stop|start) " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "toggle-ffmpeg-thumbnailer: prompting then choosing Disable masks the units" {
    _queue_answers "Disable"

    _run_thumbnailer toggle-thumbnailer.sh

    [ "${status}" -eq 0 ]
    run grep -q "^systemctl --user mask " <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "toggle-ffmpeg-thumbnailer: prompting then choosing Enable unmasks the units" {
    _queue_answers "Enable"

    _run_thumbnailer toggle-thumbnailer.sh MOCK_MASKED=1

    [ "${status}" -eq 0 ]
    run grep -q "^systemctl --user unmask " <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "toggle-ffmpeg-thumbnailer: a missing thumbnailer is reported, not masked" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=disable MOCK_UNIT_PRESENT=0
    result="${output}"

    [ "${status}" -eq 0 ]
    [[ "${result}" == *"not installed"* ]]
    run grep -Eq "^systemctl --user (mask|unmask|stop|start) " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "toggle-ffmpeg-thumbnailer: a failed mask exits non-zero and explains why" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=disable MOCK_MASK_STATUS=1
    result="${output}"

    [ "${status}" -eq 1 ]
    [[ "${result}" == *"Failed to disable"* ]]
}

@test "toggle-ffmpeg-thumbnailer: a failed unmask exits non-zero and explains why" {
    _run_thumbnailer toggle-thumbnailer.sh ACTION=enable MOCK_UNMASK_STATUS=1
    result="${output}"

    [ "${status}" -eq 1 ]
    [[ "${result}" == *"Failed to enable"* ]]
}

# --- ffmpeg thumbnailer status ------------------------------------------------

@test "status-ffmpeg-thumbnailer: reports every unit's enabled and active state" {
    _run_thumbnailer status-thumbnailer.sh \
        MOCK_MASKED=1 MOCK_ACTIVE_STATE=inactive XDG_CACHE_HOME="${WORKDIR}/cache"
    result="${output}"

    [ "${status}" -eq 0 ]
    for unit in ffmpeg-thumbnailer.service ffmpeg-thumbnailer-nvidia.service \
        ffmpeg-thumbnailer-daemon.service; do
        [[ "${result}" == *"${unit}"* ]]
    done
    [[ "${result}" == *"masked"* ]]
    [[ "${result}" == *"inactive"* ]]
}

@test "status-ffmpeg-thumbnailer: never changes unit state" {
    _run_thumbnailer status-thumbnailer.sh XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    run grep -Eq "^systemctl --user (mask|unmask|stop|start|enable) " <<< "$(_calls)"
    [ "${status}" -ne 0 ]
}

@test "status-ffmpeg-thumbnailer: reports a listening daemon socket" {
    _make_socket

    _run_thumbnailer status-thumbnailer.sh XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"listening"* ]]
}

@test "status-ffmpeg-thumbnailer: reports a missing daemon socket" {
    _run_thumbnailer status-thumbnailer.sh XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"daemon not running"* ]]
}

@test "status-ffmpeg-thumbnailer: reports a stale non-socket path" {
    mkdir -p "$(dirname "$(_socket_path)")"
    : > "$(_socket_path)"

    _run_thumbnailer status-thumbnailer.sh XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"present but not a socket"* ]]
}

@test "status-ffmpeg-thumbnailer: reports a running container" {
    _run_thumbnailer status-thumbnailer.sh XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Up 2 hours"* ]]
    run grep -q "^podman ps " <<< "$(_calls)"
    [ "${status}" -eq 0 ]
}

@test "status-ffmpeg-thumbnailer: reports a container that was never created" {
    _run_thumbnailer status-thumbnailer.sh MOCK_CONTAINER_EXISTS=1 XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"not created"* ]]
}

@test "status-ffmpeg-thumbnailer: degrades when podman is absent" {
    rm -f "${WORKDIR}/bin/podman"

    _run_thumbnailer status-thumbnailer.sh XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"podman is not installed"* ]]
}

@test "status-ffmpeg-thumbnailer: shows recent daemon activity" {
    _run_thumbnailer status-thumbnailer.sh XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"listening on /tmp/x.sock"* ]]
}

@test "status-ffmpeg-thumbnailer: says so when the journal has no entries" {
    _run_thumbnailer status-thumbnailer.sh MOCK_JOURNAL_ENTRIES=0 XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"no journal entries recorded"* ]]
}

@test "status-ffmpeg-thumbnailer: reports unknown state instead of failing" {
    rm -f "${WORKDIR}/bin/podman" "${WORKDIR}/bin/journalctl"

    _run_thumbnailer status-thumbnailer.sh MOCK_STATE_FAIL=1 XDG_CACHE_HOME="${WORKDIR}/cache"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"unknown"* ]]
}

