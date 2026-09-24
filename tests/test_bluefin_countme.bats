#!/usr/bin/env bats

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export STATE_DIRECTORY="${TEST_TMPDIR}/state"
    export IMAGE_INFO_FILE="${TEST_TMPDIR}/image-info.json"
    export BOOTED_IMAGE_FILE="${TEST_TMPDIR}/booted-image"
    export WAYLAND_SESSIONS_DIR="${TEST_TMPDIR}/wayland-sessions"
    export MOCK_BIN="${TEST_TMPDIR}/bin"
    mkdir -p "${STATE_DIRECTORY}" "${MOCK_BIN}" "${WAYLAND_SESSIONS_DIR}"

    # Mock curl to inspect executed args/URL
    cat << 'CURL_EOF' > "${MOCK_BIN}/curl"
#!/usr/bin/env bash
echo "$@" >> "${STATE_DIRECTORY}/curl_calls.log"
exit 0
CURL_EOF
    chmod +x "${MOCK_BIN}/curl"

    # Mock bootc to prevent real host bootc from interfering
    cat << 'BOOTC_EOF' > "${MOCK_BIN}/bootc"
#!/usr/bin/env bash
exit 1
BOOTC_EOF
    chmod +x "${MOCK_BIN}/bootc"

    export PATH="${MOCK_BIN}:${PATH}"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}
set_fake_now() {
    export COUNTME_TEST_NOW="$1"
    cat << 'DATE_EOF' > "${MOCK_BIN}/date"
#!/usr/bin/env bash
printf '%s\n' "$COUNTME_TEST_NOW"
DATE_EOF
    chmod +x "${MOCK_BIN}/date"
}


@test "bluefin-countme generates epoch and sends countme=1 on first run for dakota" {
    cat << 'EOF' > "${IMAGE_INFO_FILE}"
{
  "image-name": "dakota",
  "image-flavor": "main",
  "image-tag": "stable"
}
EOF

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]

    [ -f "${STATE_DIRECTORY}/epoch" ]
    [ -f "${STATE_DIRECTORY}/lastrun" ]

    run cat "${STATE_DIRECTORY}/curl_calls.log"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "repo=dakota" ]]
    [[ "$output" =~ "tag=stable" ]]
    [[ "$output" =~ "flavor=main" ]]
    [[ "$output" =~ "gamemode=0" ]]
    [[ "$output" =~ "countme=1" ]]
}

@test "bluefin-countme detects testing tag and gaming mode" {
    cat << 'EOF' > "${IMAGE_INFO_FILE}"
{
  "image-name": "dakota-gaming",
  "image-flavor": "gaming",
  "image-tag": "testing"
}
EOF

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]

    run cat "${STATE_DIRECTORY}/curl_calls.log"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "repo=dakota" ]]
    [[ "$output" =~ "tag=testing" ]]
    [[ "$output" =~ "flavor=gaming" ]]
    [[ "$output" =~ "gamemode=1" ]]
}

@test "bluefin-countme throttles execution within weekly window" {
    cat << 'EOF' > "${IMAGE_INFO_FILE}"
{
  "image-name": "dakota",
  "image-flavor": "main",
  "image-tag": "stable"
}
EOF

    # First run
    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]
    [ -f "${STATE_DIRECTORY}/curl_calls.log" ]
    calls_1=$(wc -l < "${STATE_DIRECTORY}/curl_calls.log")

    # Immediate second run (within throttle window)
    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]
    calls_2=$(wc -l < "${STATE_DIRECTORY}/curl_calls.log")

    [ "$calls_1" -eq "$calls_2" ]
}

@test "a successful ping cannot repeat within the same UTC week" {
    printf '{"image-name":"dakota","image-tag":"stable"}\n' > "${IMAGE_INFO_FILE}"
    last=$(date -u -d '2026-09-21T00:00:00Z' +%s)
    now=$(date -u -d '2026-09-27T12:00:00Z' +%s)
    printf '%s\n' "$last" > "${STATE_DIRECTORY}/lastrun"
    set_fake_now "$now"

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]
    [ ! -f "${STATE_DIRECTORY}/curl_calls.log" ]
}

@test "a new UTC week can report even after a recent ping" {
    printf '{"image-name":"dakota","image-tag":"testing"}\n' > "${IMAGE_INFO_FILE}"
    last=$(date -u -d '2026-09-27T23:30:00Z' +%s)
    now=$(date -u -d '2026-09-28T00:15:00Z' +%s)
    printf '%s\n' "$last" > "${STATE_DIRECTORY}/lastrun"
    set_fake_now "$now"

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]
    [ -f "${STATE_DIRECTORY}/curl_calls.log" ]
    [ "$(< "${STATE_DIRECTORY}/lastrun")" -eq "$now" ]
}

@test "a failed upload returns failure and leaves this week retryable" {
    printf '{"image-name":"dakota","image-tag":"testing"}\n' > "${IMAGE_INFO_FILE}"
    printf '#!/usr/bin/env bash\nexit 22\n' > "${MOCK_BIN}/curl"
    chmod +x "${MOCK_BIN}/curl"

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 22 ]
    [ ! -f "${STATE_DIRECTORY}/lastrun" ]
}

@test "bluefin-countme calculates bucket based on epoch age" {
    cat << 'EOF' > "${IMAGE_INFO_FILE}"
{
  "image-name": "dakota",
  "image-flavor": "main",
  "image-tag": "stable"
}
EOF
    # Set epoch to 3 weeks ago (bucket 2)
    now=$(date +%s)
    three_weeks_ago=$(( now - (3 * 7 * 86400) ))
    echo "$three_weeks_ago" > "${STATE_DIRECTORY}/epoch"

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]

    run cat "${STATE_DIRECTORY}/curl_calls.log"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "countme=2" ]]
}

@test "bluefin-countme exits 0 without calling countme endpoint on non-dakota images" {
    cat << 'EOF' > "${IMAGE_INFO_FILE}"
{
  "image-name": "bluefin-lts",
  "image-flavor": "main",
  "image-tag": "stable"
}
EOF

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]
    [ ! -f "${STATE_DIRECTORY}/curl_calls.log" ]
}

@test "bluefin-countme extracts runtime tag from bootc mock" {
    cat << 'EOF' > "${IMAGE_INFO_FILE}"
{
  "image-name": "dakota",
  "image-flavor": "main",
  "image-tag": "stable"
}
EOF

    cat << 'BOOTC_EOF' > "${MOCK_BIN}/bootc"
#!/usr/bin/env bash
cat << 'JSON'
{
  "status": {
    "booted": {
      "image": {
        "image": {
          "image": "ghcr.io/projectbluefin/dakota:testing"
        }
      }
    }
  }
}
JSON
BOOTC_EOF
    chmod +x "${MOCK_BIN}/bootc"

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]

    run cat "${STATE_DIRECTORY}/curl_calls.log"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tag=testing" ]]
}
@test "a missing booted stream does not invent a latest count" {
    printf '{"image-name":"dakota","image-tag":"latest"}\n' > "${IMAGE_INFO_FILE}"

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -ne 0 ]
    [ ! -f "${STATE_DIRECTORY}/curl_calls.log" ]
    [ ! -f "${STATE_DIRECTORY}/lastrun" ]
}

@test "missing image and booted tags cannot invent stable check-ins" {
    printf '{"image-name":"dakota"}\n' > "${IMAGE_INFO_FILE}"

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -ne 0 ]
    [ ! -f "${STATE_DIRECTORY}/curl_calls.log" ]
    [ ! -f "${STATE_DIRECTORY}/lastrun" ]
}

@test "digest-pinned booted ref retains its testing tag" {
    printf '{"image-name":"dakota","image-tag":"latest"}\n' > "${IMAGE_INFO_FILE}"
    printf 'ghcr.io/projectbluefin/dakota:testing@sha256:abc123\n' > "${BOOTED_IMAGE_FILE}"

    run bash system_files/shared/usr/libexec/bluefin-countme
    [ "$status" -eq 0 ]
    run cat "${STATE_DIRECTORY}/curl_calls.log"
    [[ "$output" =~ "tag=testing" ]]
}
