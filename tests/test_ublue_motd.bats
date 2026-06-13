#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/ublue-motd and related profile.d scripts
#
# Run: bats tests/test_ublue_motd.bats

bats_require_minimum_version 1.5.0

SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/bin/ublue-motd"
UBLUE_MOTD_PROFILE_SCRIPT="${BATS_TEST_DIRNAME}/../system_files/shared/etc/profile.d/ublue-motd.sh"
UMOTD_PROFILE_SCRIPT="${BATS_TEST_DIRNAME}/../system_files/shared/etc/profile.d/umotd.sh"
TOGGLE_MOTD_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/default.just"
WORKDIR=""
MOCKDIR=""
LOGDIR=""

write_mock() {
    local name="$1"
    cat > "${MOCKDIR}/${name}"
    chmod +x "${MOCKDIR}/${name}"
}

setup() {
    local safe_test_name="${BATS_TEST_NAME//[^[:alnum:]]/_}"
    WORKDIR="${BATS_TEST_DIRNAME}/.bats-work/${safe_test_name}-$$"
    MOCKDIR="${WORKDIR}/bin"
    LOGDIR="${WORKDIR}/logs"

    mkdir -p "${MOCKDIR}" "${LOGDIR}" "${WORKDIR}/home/.config"

    export HOME="${WORKDIR}/home"
    export MOCK_LOG_DIR="${LOGDIR}"
    export PATH="${MOCKDIR}:/usr/bin:/bin"
    export MOTD_TEMPLATE_FILE="${WORKDIR}/template.md"
    export MOTD_ENV_SCRIPT="${WORKDIR}/env.sh"

    cat > "${MOTD_ENV_SCRIPT}" <<'EOF'
#!/usr/bin/env sh
export TEST_VALUE="Bluefin"
EOF
    chmod +x "${MOTD_ENV_SCRIPT}"

    cat > "${MOTD_TEMPLATE_FILE}" <<'EOF'
Welcome $TEST_VALUE
EOF

    write_mock envsubst <<'EOF'
#!/usr/bin/env bash
content="$(cat)"
printf '%s' "${content}" > "${MOCK_LOG_DIR}/envsubst.stdin"
printf '%s' "${content//\$TEST_VALUE/${TEST_VALUE}}"
EOF

    write_mock tput <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${MOCK_LOG_DIR}/tput.args"
printf '120\n'
EOF

    write_mock glow <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${MOCK_LOG_DIR}/glow.args"
content="$(cat)"
printf '%s' "${content}" > "${MOCK_LOG_DIR}/glow.stdin"
printf '%s' "${content}"
EOF

    write_mock ublue-motd <<'EOF'
#!/usr/bin/env bash
printf 'ublue-motd\n' >> "${MOCK_LOG_DIR}/profile.log"
EOF

    write_mock umotd <<'EOF'
#!/usr/bin/env bash
printf 'umotd\n' >> "${MOCK_LOG_DIR}/profile.log"
EOF
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "ublue-motd: missing template skips envsubst and produces no rendered output" {
    rm -f "${MOTD_TEMPLATE_FILE}"

    run "${SCRIPT_UNDER_TEST}"

    [ "${status}" -eq 0 ]
    [ ! -e "${LOGDIR}/envsubst.stdin" ]
    grep -qx -- "-" "${LOGDIR}/glow.args"
    [ ! -s "${LOGDIR}/glow.stdin" ]
}

@test "ublue-motd: passes template content through envsubst" {
    cat > "${MOTD_TEMPLATE_FILE}" <<'EOF'
Hello $TEST_VALUE
EOF

    run "${SCRIPT_UNDER_TEST}"

    [ "${status}" -eq 0 ]
    grep -qx -- 'Hello $TEST_VALUE' "${LOGDIR}/envsubst.stdin"
}

@test "ublue-motd: non-tty path skips tput and uses glow fallback args" {
    run "${SCRIPT_UNDER_TEST}"

    [ "${status}" -eq 0 ]
    [ ! -e "${LOGDIR}/tput.args" ]
    grep -qx -- "-" "${LOGDIR}/glow.args"
}

@test "ublue-motd: renders output through glow when available" {
    cat > "${MOTD_TEMPLATE_FILE}" <<'EOF'
Rendered $TEST_VALUE
EOF

    run "${SCRIPT_UNDER_TEST}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "Rendered Bluefin" ]
    [ "$(cat "${LOGDIR}/glow.stdin")" = "Rendered Bluefin" ]
}

@test "ublue-motd: exits non-zero when glow is unavailable" {
    write_mock glow <<'EOF'
#!/usr/bin/env bash
printf 'glow: command not found\n' >&2
exit 127
EOF

    run -127 "${SCRIPT_UNDER_TEST}"

    [ "${status}" -eq 127 ]
    [[ "${output}" == *"glow: command not found"* ]]
}

@test "ublue-motd: normal output path expands variables" {
    cat > "${MOTD_TEMPLATE_FILE}" <<'EOF'
Normal $TEST_VALUE output
EOF

    run "${SCRIPT_UNDER_TEST}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "Normal Bluefin output" ]
}

@test "ublue-motd.sh: suppresses motd when opt-out file exists" {
    touch "${HOME}/.config/no-show-user-motd"

    run bash "${UBLUE_MOTD_PROFILE_SCRIPT}"

    [ "${status}" -eq 1 ]
    [ ! -e "${LOGDIR}/profile.log" ]
}

@test "ublue-motd.sh: invokes ublue-motd when opt-out file is absent" {
    run bash "${UBLUE_MOTD_PROFILE_SCRIPT}"

    [ "${status}" -eq 0 ]
    grep -qx -- "ublue-motd" "${LOGDIR}/profile.log"
}

# Extract the toggle-user-motd recipe body from default.just into a runnable script
_extract_toggle_recipe() {
    local dest="$1"
    awk '/^toggle-user-motd:$/{in_r=1;next} in_r && /^    /{sub(/^    /,"");print;next} in_r && !/^[[:space:]]/{exit}' \
        "${TOGGLE_MOTD_JUST}" > "${dest}"
    chmod +x "${dest}"
}

@test "toggle-user-motd: exits 0 when motd is enabled and user declines to disable" {
    local script="${WORKDIR}/toggle.sh"
    _extract_toggle_recipe "${script}"

    # Mock gum to simulate 'No' (exit 1)
    write_mock gum <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

    run bash "${script}"

    [ "${status}" -eq 0 ]
}

@test "toggle-user-motd: exits 0 when motd is disabled and user declines to re-enable" {
    local script="${WORKDIR}/toggle.sh"
    _extract_toggle_recipe "${script}"

    # Disable motd first
    touch "${HOME}/.config/no-show-user-motd"

    # Mock gum to simulate 'No' (exit 1) — should not fall through to the disable prompt
    write_mock gum <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

    run bash "${script}"

    [ "${status}" -eq 0 ]
    # Motd should remain disabled (file untouched)
    [ -e "${HOME}/.config/no-show-user-motd" ]
}

@test "toggle-user-motd: exits 0 and removes opt-out file when user confirms enable" {
    local script="${WORKDIR}/toggle.sh"
    _extract_toggle_recipe "${script}"

    touch "${HOME}/.config/no-show-user-motd"

    # Mock gum to simulate 'Yes' (exit 0)
    write_mock gum <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    run bash "${script}"

    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.config/no-show-user-motd" ]
}

@test "toggle-user-motd: exits 0 and creates opt-out file when user confirms disable" {
    local script="${WORKDIR}/toggle.sh"
    _extract_toggle_recipe "${script}"

    # Motd currently enabled (no opt-out file)
    write_mock gum <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    run bash "${script}"

    [ "${status}" -eq 0 ]
    [ -e "${HOME}/.config/no-show-user-motd" ]
}

@test "umotd.sh: invokes umotd unconditionally" {
    touch "${HOME}/.config/no-show-user-motd"

    run bash "${UMOTD_PROFILE_SCRIPT}"

    [ "${status}" -eq 0 ]
    grep -qx -- "umotd" "${LOGDIR}/profile.log"
}
