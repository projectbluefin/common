#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/ublue-fastfetch
#
# Strategy: run the script as a subprocess with mocked PATH entries for
# fastfetch, ublue-bling-fastfetch, and FASTFETCH_CONFIG_FILE pointed at a
# temp JSON config.  exec fastfetch replaces the subprocess — the mock
# records its args to a log file before exiting so assertions can read it.
#
# Hardware note: fastfetch itself is not tested here.  These tests cover the
# pure logic: config key reads, shuffle branch selection, DEFAULT_THEME export.
#
# Run: bats tests/test_ublue_fastfetch.bats

SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/bin/ublue-fastfetch"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"
    mkdir -p "${WORKDIR}/logos"

    # Mock ublue-bling-fastfetch — returns a fixed colour name
    printf '#!/bin/bash\necho "blue"\n' > "${WORKDIR}/bin/ublue-bling-fastfetch"
    chmod +x "${WORKDIR}/bin/ublue-bling-fastfetch"

    # Mock fastfetch — records all args to a log file, exits 0
    # The log path is baked into the mock so exec replacement preserves it.
    printf '#!/bin/bash\necho "$@" >> %s/fastfetch.log\n' "${WORKDIR}" \
        > "${WORKDIR}/bin/fastfetch"
    chmod +x "${WORKDIR}/bin/fastfetch"

    # A real logo file so shuffle tests have something to pick
    touch "${WORKDIR}/logos/dino.png"

    # Default config — shuffle off
    cat > "${WORKDIR}/fastfetch.json" <<EOF
{
  "fastfetch-config": "/usr/share/ublue-os/fastfetch.jsonc",
  "shuffle-logo": "false",
  "logo-directory": "${WORKDIR}/logos",
  "default-theme": "slate"
}
EOF

    export PATH="${WORKDIR}/bin:${PATH}"
    export FASTFETCH_CONFIG_FILE="${WORKDIR}/fastfetch.json"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "ublue-fastfetch: invokes fastfetch without --logo when shuffle disabled" {
    run bash "${SCRIPT_UNDER_TEST}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/fastfetch.log" ]
    ! grep -q -- "--logo" "${WORKDIR}/fastfetch.log"
}

@test "ublue-fastfetch: passes --config value from json to fastfetch" {
    run bash "${SCRIPT_UNDER_TEST}"
    [ "${status}" -eq 0 ]
    grep -q -- "--config /usr/share/ublue-os/fastfetch.jsonc" "${WORKDIR}/fastfetch.log"
}

@test "ublue-fastfetch: passes --color from ublue-bling-fastfetch to fastfetch" {
    run bash "${SCRIPT_UNDER_TEST}"
    [ "${status}" -eq 0 ]
    grep -q -- "--color blue" "${WORKDIR}/fastfetch.log"
}

@test "ublue-fastfetch: invokes fastfetch with --logo when shuffle enabled" {
    cat > "${WORKDIR}/fastfetch.json" <<EOF
{
  "fastfetch-config": "/usr/share/ublue-os/fastfetch.jsonc",
  "shuffle-logo": "true",
  "logo-directory": "${WORKDIR}/logos",
  "default-theme": "slate"
}
EOF
    run bash "${SCRIPT_UNDER_TEST}"
    [ "${status}" -eq 0 ]
    grep -q -- "--logo" "${WORKDIR}/fastfetch.log"
}

@test "ublue-fastfetch: uses fallback config path when config file is missing" {
    export FASTFETCH_CONFIG_FILE="/nonexistent/fastfetch.json"
    run bash "${SCRIPT_UNDER_TEST}"
    [ "${status}" -eq 0 ]
    grep -q -- "--config /usr/share/ublue-os/fastfetch.jsonc" "${WORKDIR}/fastfetch.log"
}

@test "ublue-fastfetch: exports DEFAULT_THEME to ublue-bling-fastfetch subprocess" {
    # ublue-bling-fastfetch is the documented consumer of DEFAULT_THEME (comment in
    # the script: '# Gets passed to ublue-bling-fastfetch'). Override that mock to
    # record the env var it receives so a missing 'export' would be caught.
    printf '#!/bin/bash\necho "DEFAULT_THEME=${DEFAULT_THEME}" >> %s/bling.log\necho "blue"\n' \
        "${WORKDIR}" > "${WORKDIR}/bin/ublue-bling-fastfetch"
    chmod +x "${WORKDIR}/bin/ublue-bling-fastfetch"

    cat > "${WORKDIR}/fastfetch.json" <<EOF
{
  "fastfetch-config": "/usr/share/ublue-os/fastfetch.jsonc",
  "shuffle-logo": "false",
  "logo-directory": "${WORKDIR}/logos",
  "default-theme": "mocha"
}
EOF
    run bash "${SCRIPT_UNDER_TEST}"
    [ "${status}" -eq 0 ]
    grep -q "DEFAULT_THEME=mocha" "${WORKDIR}/bling.log"
}

@test "ublue-fastfetch: DEFAULT_THEME falls back to 'slate' when key is absent" {
    printf '#!/bin/bash\necho "DEFAULT_THEME=${DEFAULT_THEME}" >> %s/bling.log\necho "blue"\n' \
        "${WORKDIR}" > "${WORKDIR}/bin/ublue-bling-fastfetch"
    chmod +x "${WORKDIR}/bin/ublue-bling-fastfetch"

    cat > "${WORKDIR}/fastfetch.json" <<EOF
{
  "fastfetch-config": "/usr/share/ublue-os/fastfetch.jsonc",
  "shuffle-logo": "false",
  "logo-directory": "${WORKDIR}/logos"
}
EOF
    run bash "${SCRIPT_UNDER_TEST}"
    [ "${status}" -eq 0 ]
    grep -q "DEFAULT_THEME=slate" "${WORKDIR}/bling.log"
}

@test "ublue-fastfetch: extra CLI args are forwarded to fastfetch" {
    run bash "${SCRIPT_UNDER_TEST}" --modules cpu
    [ "${status}" -eq 0 ]
    grep -q -- "--modules cpu" "${WORKDIR}/fastfetch.log"
}
