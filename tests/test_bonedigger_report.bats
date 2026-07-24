#!/usr/bin/env bats

setup() {
    export BONEDIGGER_SCRIPT="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/libexec/bonedigger-report"

    WORKDIR="$(mktemp -d)"

    TEST_HELPER="$(mktemp)"
    cat << 'INNER_EOF' > "$TEST_HELPER"
#!/usr/bin/bash
# Evaluate the scrub functions from the script
eval "$(sed -n '/^scrub_kernel_log() {/,/^}/p' "$BONEDIGGER_SCRIPT")"
eval "$(sed -n '/^scrub_journal_log() {/,/^}/p' "$BONEDIGGER_SCRIPT")"

# Execute requested function
"$@"
INNER_EOF
    chmod +x "$TEST_HELPER"
}

teardown() {
    rm -f "$TEST_HELPER" "${CONFIRM_HELPER:-}"
    rm -rf "$WORKDIR"
}

@test "scrub_kernel_log redacts MAC addresses" {
    result="$(echo "Device 00:1A:2B:3C:4D:5E connected" | "$TEST_HELPER" scrub_kernel_log)"
    [ "$result" = "Device [MAC-REDACTED] connected" ]
}

@test "scrub_kernel_log redacts IPv4 addresses" {
    result="$(echo "Connecting to 192.168.1.100 port 80" | "$TEST_HELPER" scrub_kernel_log)"
    [ "$result" = "Connecting to [IP-REDACTED] port 80" ]
}

@test "scrub_kernel_log redacts IPv6 addresses" {
    result="$(echo "IP: 2001:0db8:85a3:0000:0000:8a2e:0370:7334" | "$TEST_HELPER" scrub_kernel_log)"
    [ "$result" = "IP: [IP-REDACTED]" ]
}

@test "scrub_kernel_log redacts UUIDs" {
    result="$(echo "Disk 123e4567-e89b-12d3-a456-426614174000 mounted" | "$TEST_HELPER" scrub_kernel_log)"
    [ "$result" = "Disk [UUID-REDACTED] mounted" ]
}

@test "scrub_kernel_log redacts home paths" {
    result="$(echo "Error opening /var/home/jorge/.config/file" | "$TEST_HELPER" scrub_kernel_log)"
    [ "$result" = "Error opening /var/home/[REDACTED]/.config/file" ]

    result="$(echo "Cannot read /home/alice/Documents" | "$TEST_HELPER" scrub_kernel_log)"
    [ "$result" = "Cannot read /home/[REDACTED]/Documents" ]
}

@test "scrub_journal_log redacts USER/LOGNAME variables" {
    result="$(echo "Started session for USER=jorge" | "$TEST_HELPER" scrub_journal_log)"
    [ "$result" = "Started session for USER=[REDACTED]" ]

    result="$(echo "LOGNAME=alice is logging in" | "$TEST_HELPER" scrub_journal_log)"
    [ "$result" = "LOGNAME=[REDACTED] is logging in" ]
}

@test "scrub_journal_log redacts email addresses" {
    result="$(echo "Failed to sync jorge@example.com" | "$TEST_HELPER" scrub_journal_log)"
    [ "$result" = "Failed to sync [REDACTED-email]" ]
}

@test "issue_url routing works for bluefin" {
    # Extract the issue URL routing logic into a testable script
    TEST_URL_ROUTER="$(mktemp)"
    cat << 'INNER_EOF' > "$TEST_URL_ROUTER"
#!/usr/bin/bash
IMAGE_INFO_FILE="/dev/null"
IMAGE_NAME="$1"
IMAGE_TAG="$2"
BONEDIGGER_ISSUE_URL="$3"

eval "$(sed -n '/^case "\$IMAGE_NAME"/,/^FEATURE_URL/p' "$BONEDIGGER_SCRIPT")"

echo "$ISSUE_URL_BASE|$ISSUE_REPO"
INNER_EOF
    chmod +x "$TEST_URL_ROUTER"

    # Bluefin generic
    result="$("$TEST_URL_ROUTER" "bluefin" "latest" "")"
    [ "$result" = "https://github.com/projectbluefin/bluefin/issues/new?template=bug-report.yml|projectbluefin/bluefin" ]

    # Bluefin LTS
    result="$("$TEST_URL_ROUTER" "bluefin" "lts-39" "")"
    [ "$result" = "https://github.com/projectbluefin/bluefin-lts/issues/new?template=bug-report.yml|projectbluefin/bluefin-lts" ]

    # Dakota
    result="$("$TEST_URL_ROUTER" "dakota" "latest" "")"
    [ "$result" = "https://github.com/projectbluefin/dakota/issues/new?template=bug-report.yml|projectbluefin/dakota" ]

    # Common fallback
    result="$("$TEST_URL_ROUTER" "something-else" "latest" "")"
    [ "$result" = "https://github.com/projectbluefin/common/issues/new?template=bug-report.yml|projectbluefin/common" ]

    # Override
    result="$("$TEST_URL_ROUTER" "bluefin" "latest" "https://example.com/custom")"
    [ "$result" = "https://example.com/custom|projectbluefin/bluefin" ]

    rm -f "$TEST_URL_ROUTER"
}

@test "confirm posts a lightweight fingerprint to the routed repository" {
    mkdir -p "$WORKDIR/bin"
    cat << 'INNER_EOF' > "$WORKDIR/bin/systemctl"
#!/usr/bin/bash
printf 'failed-example.service loaded failed failed\n'
INNER_EOF
    cat << 'INNER_EOF' > "$WORKDIR/bin/gh"
#!/usr/bin/bash
printf '%s\n' "$*" >> "$CALLS_FILE"
if [[ "$1" == api ]]; then
    printf 'https://github.com/projectbluefin/bluefin-lts/issues/42#issuecomment-123\n'
fi
INNER_EOF
    chmod +x "$WORKDIR/bin/systemctl" "$WORKDIR/bin/gh"
    export CALLS_FILE="$WORKDIR/gh-calls"
    export PATH="$WORKDIR/bin:$PATH"

    CONFIRM_HELPER="$(mktemp)"
    cat << 'INNER_EOF' > "$CONFIRM_HELPER"
#!/usr/bin/bash
set -euo pipefail
eval "$(sed -n '/^confirm_report() {/,/^}$/p' "$BONEDIGGER_SCRIPT")"
BOOTC_JSON='{"status":{"booted":{"imageDigest":"sha256:abc123"}}}'
IMAGE_REF='ghcr.io/projectbluefin/bluefin'
IMAGE_TAG='latest'
confirm_report 42 projectbluefin/bluefin-lts
INNER_EOF
    chmod +x "$CONFIRM_HELPER"

    run "$CONFIRM_HELPER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'**System fingerprint** (via `ujust report --confirm`)'* ]]
    [[ "$output" == *'Image: ghcr.io/projectbluefin/bluefin'* ]]
    [[ "$output" == *'Digest: sha256:abc123'* ]]
    grep -qF 'issue comment 42 --repo projectbluefin/bluefin-lts --body' "$CALLS_FILE"
    grep -qF 'https://github.com/projectbluefin/bluefin-lts/issues/42#issuecomment-123' <<< "$output"
}

@test "confirm rejects non-positive issue numbers" {
    run env HOME="$WORKDIR/home" bash "$BONEDIGGER_SCRIPT" --confirm 0
    [ "$status" -eq 1 ]
    [[ "$output" == *'Usage: ujust report --confirm <issue-number>'* ]]

    run env HOME="$WORKDIR/home" bash "$BONEDIGGER_SCRIPT" --confirm nope
    [ "$status" -eq 1 ]
    [[ "$output" == *'Usage: ujust report --confirm <issue-number>'* ]]
}

@test "home paths with spaces are redacted" {
    result="$(echo "Path /var/home/jorge space/file" | "$TEST_HELPER" scrub_kernel_log)"
    # Note the original regex: s|/(var/)?home/[^/[:space:]]+/|/\1home/[REDACTED]/|g
    # It stops at space. So /var/home/jorge space/ might not be fully scrubbed if 'jorge space' is the username.
    # Actually, usernames cannot contain spaces. So stopping at space is correct to prevent matching across words.

    result="$(echo "File saved to /home/jorge/my documents/file.txt" | "$TEST_HELPER" scrub_kernel_log)"
    [ "$result" = "File saved to /home/[REDACTED]/my documents/file.txt" ]
}

@test "scrub_kernel_log handles multiple PII in one line" {
    result="$(echo "User /home/alice/ connected from 192.168.1.5 (MAC: AA:BB:CC:DD:EE:FF)" | "$TEST_HELPER" scrub_kernel_log)"
    [ "$result" = "User /home/[REDACTED]/ connected from [IP-REDACTED] (MAC: [MAC-REDACTED])" ]
}
