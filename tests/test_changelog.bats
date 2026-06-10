#!/usr/bin/env bats
# Tests for the changelog.just repo-selection and fetch logic
#
# Run: bats tests/test_changelog.bats
#
# Strategy: extract the bash body from changelog.just, inject it into a
# sub-shell with mocked binaries (jq, curl, glow, grep) and a mock
# image-info.json so we never hit the network or the real filesystem.

CHANGELOG_JUST="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/share/ublue-os/just/changelog.just"
WORKDIR=""

# Extract the bash body from the just recipe (skip recipe header + shebang,
# strip the 4-space just indentation) and write it to a temp file.
_extract_script() {
    local out_file="$1"
    awk '
        /^    #!\/usr\/bin\/bash/ { found=1; next }
        found { sub(/^    /, ""); print }
    ' "${CHANGELOG_JUST}" > "${out_file}"
}

setup() {
    WORKDIR="$(mktemp -d)"
    MOCKDIR="${WORKDIR}/bin"
    mkdir -p "${MOCKDIR}"

    # Capture file — curl writes each URL it receives here
    CURL_CALLS="${WORKDIR}/curl_calls"
    touch "${CURL_CALLS}"
    export CURL_CALLS

    # Mock jq:
    #   - '.["image-tag"]' query  → returns $MOCK_TAG
    #   - all other invocations   → echo a mock changelog body
    cat > "${MOCKDIR}/jq" << 'EOF'
#!/bin/bash
for arg in "$@"; do
    if [[ "$arg" == *'image-tag'* ]]; then
        echo "${MOCK_TAG:-latest}"
        exit 0
    fi
done
# Release body extraction or latest .body
echo "mock changelog body"
EOF
    chmod +x "${MOCKDIR}/jq"

    # Mock curl: record the URL, return a JSON array with one release entry
    cat > "${MOCKDIR}/curl" << 'CURLEOF'
#!/bin/bash
for arg in "$@"; do
    if [[ "$arg" =~ ^https:// ]]; then
        echo "$arg" >> "${CURL_CALLS}"
    fi
done
echo '[{"tag_name":"stable-20260601","body":"mock changelog"}]'
CURLEOF
    chmod +x "${MOCKDIR}/curl"

    # Mock glow: passthrough (just print stdin)
    printf '#!/bin/bash\ncat\n' > "${MOCKDIR}/glow"
    chmod +x "${MOCKDIR}/glow"

    # Mock grep: used for DATE extraction — return a fixed date string
    cat > "${MOCKDIR}/grep" << 'EOF'
#!/bin/bash
# If called with -oP for OSTREE_VERSION date extraction, return fixed date
if [[ "$*" == *OSTREE_VERSION* ]]; then
    echo "20260601"
    exit 0
fi
# Otherwise delegate to real grep
/usr/bin/grep "$@"
EOF
    chmod +x "${MOCKDIR}/grep"

    export PATH="${MOCKDIR}:${PATH}"

    SCRIPT_FILE="${WORKDIR}/changelog.sh"
    _extract_script "${SCRIPT_FILE}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# Repo selection — LTS stream
# ---------------------------------------------------------------------------

@test "changelog: lts tag selects projectbluefin/bluefin-lts repo" {
    MOCK_TAG="lts-20260601" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
    grep -q "projectbluefin/bluefin-lts" "${CURL_CALLS}"
}

@test "changelog: lts tag does NOT query projectbluefin/bluefin" {
    MOCK_TAG="lts-20260601" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
    # The bluefin (non-lts) repo must not appear in any curl call
    ! grep -q "projectbluefin/bluefin[^-]" "${CURL_CALLS}"
}

@test "changelog: lts-hwe tag selects projectbluefin/bluefin-lts repo" {
    MOCK_TAG="lts-hwe" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
    grep -q "projectbluefin/bluefin-lts" "${CURL_CALLS}"
}

# ---------------------------------------------------------------------------
# Repo selection — non-LTS streams
# ---------------------------------------------------------------------------

@test "changelog: stable tag selects projectbluefin/bluefin repo" {
    MOCK_TAG="stable" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
    grep -q "projectbluefin/bluefin" "${CURL_CALLS}"
    ! grep -q "bluefin-lts" "${CURL_CALLS}"
}

@test "changelog: gts tag selects projectbluefin/bluefin repo" {
    MOCK_TAG="gts" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
    grep -q "projectbluefin/bluefin" "${CURL_CALLS}"
    ! grep -q "bluefin-lts" "${CURL_CALLS}"
}

@test "changelog: latest tag selects projectbluefin/bluefin repo (fallback)" {
    MOCK_TAG="latest" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
    grep -q "projectbluefin/bluefin" "${CURL_CALLS}"
    ! grep -q "bluefin-lts" "${CURL_CALLS}"
}

# ---------------------------------------------------------------------------
# URL construction — release fetch path
# ---------------------------------------------------------------------------

@test "changelog: stable tag fetches from /releases endpoint (not /releases/latest)" {
    MOCK_TAG="stable" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
    # Must hit the versioned releases list, not the latest shortcut
    grep -q "api.github.com/repos/projectbluefin/bluefin/releases$" "${CURL_CALLS}" || \
    grep -qP "api\.github\.com/repos/projectbluefin/bluefin/releases$" "${CURL_CALLS}"
}

@test "changelog: latest tag falls through to /releases/latest endpoint" {
    MOCK_TAG="latest" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
    grep -q "releases/latest" "${CURL_CALLS}"
}

@test "changelog: lts tag fetches from bluefin-lts /releases endpoint" {
    MOCK_TAG="lts-20260601" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
    grep -q "api.github.com/repos/projectbluefin/bluefin-lts/releases" "${CURL_CALLS}"
}

# ---------------------------------------------------------------------------
# Exit behaviour
# ---------------------------------------------------------------------------

@test "changelog: exits 0 on stable tag" {
    MOCK_TAG="stable" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
}

@test "changelog: exits 0 on latest tag (fallback path)" {
    MOCK_TAG="latest" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
}

@test "changelog: exits 0 on lts tag" {
    MOCK_TAG="lts-20260601" run bash "${SCRIPT_FILE}"
    [ "${status}" -eq 0 ]
}
