#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/ublue-bling-fastfetch
#
# Run: bats tests/test_bling_fastfetch.bats

SCRIPT="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ublue-bling-fastfetch"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    MOCKDIR="${WORKDIR}/bin"
    mkdir -p "${MOCKDIR}"

    # Mock dconf — returns empty string by default (simulates unset accent-color)
    printf '#!/bin/bash\necho ""\n' > "${MOCKDIR}/dconf"
    chmod +x "${MOCKDIR}/dconf"

    # Mock gsettings — returns empty string by default
    printf '#!/bin/bash\necho ""\n' > "${MOCKDIR}/gsettings"
    chmod +x "${MOCKDIR}/gsettings"

    export PATH="${MOCKDIR}:${PATH}"
    unset FASTFETCH_FORCE_THEME
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# FASTFETCH_FORCE_THEME override — covers all 9 named colors
# ---------------------------------------------------------------------------

@test "ublue-bling-fastfetch: blue returns correct ANSI color" {
    FASTFETCH_FORCE_THEME=blue run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;53;132;228" ]
}

@test "ublue-bling-fastfetch: green returns correct ANSI color" {
    FASTFETCH_FORCE_THEME=green run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;58;148;74" ]
}

@test "ublue-bling-fastfetch: orange returns correct ANSI color" {
    FASTFETCH_FORCE_THEME=orange run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;237;91;0" ]
}

@test "ublue-bling-fastfetch: pink returns correct ANSI color" {
    FASTFETCH_FORCE_THEME=pink run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;213;97;153" ]
}

@test "ublue-bling-fastfetch: purple returns correct ANSI color" {
    FASTFETCH_FORCE_THEME=purple run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;139;62;165" ]
}

@test "ublue-bling-fastfetch: red returns correct ANSI color" {
    FASTFETCH_FORCE_THEME=red run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;230;45;66" ]
}

@test "ublue-bling-fastfetch: slate returns correct ANSI color" {
    FASTFETCH_FORCE_THEME=slate run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;111;131;150" ]
}

@test "ublue-bling-fastfetch: teal returns correct ANSI color" {
    FASTFETCH_FORCE_THEME=teal run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;33;144;164" ]
}

@test "ublue-bling-fastfetch: yellow returns correct ANSI color" {
    FASTFETCH_FORCE_THEME=yellow run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;200;136;0" ]
}

# ---------------------------------------------------------------------------
# Default / unknown theme fallback
# ---------------------------------------------------------------------------

@test "ublue-bling-fastfetch: unknown theme falls back to blue default" {
    FASTFETCH_FORCE_THEME=notacolor run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;53;132;228" ]
}

@test "ublue-bling-fastfetch: empty FASTFETCH_FORCE_THEME falls back to blue default" {
    FASTFETCH_FORCE_THEME="" run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;53;132;228" ]
}

# ---------------------------------------------------------------------------
# dconf / gsettings fallback chain
# ---------------------------------------------------------------------------

@test "ublue-bling-fastfetch: reads theme from dconf when available" {
    # dconf returns 'teal' — gsettings should not be called
    printf "#!/bin/bash\necho 'teal'\n" > "${WORKDIR}/bin/dconf"
    chmod +x "${WORKDIR}/bin/dconf"

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;33;144;164" ]
}

@test "ublue-bling-fastfetch: falls through to gsettings when dconf returns empty" {
    # dconf returns empty, gsettings returns 'orange'
    printf "#!/bin/bash\necho ''\n" > "${WORKDIR}/bin/dconf"
    printf "#!/bin/bash\necho 'orange'\n" > "${WORKDIR}/bin/gsettings"
    chmod +x "${WORKDIR}/bin/dconf" "${WORKDIR}/bin/gsettings"

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;237;91;0" ]
}

@test "ublue-bling-fastfetch: strips single quotes from dconf output" {
    # dconf returns quoted value (common dconf output format)
    printf "#!/bin/bash\necho \"'green'\"\n" > "${WORKDIR}/bin/dconf"
    chmod +x "${WORKDIR}/bin/dconf"

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;58;148;74" ]
}

@test "ublue-bling-fastfetch: FASTFETCH_FORCE_THEME takes precedence over dconf" {
    # dconf would return 'red', but FASTFETCH_FORCE_THEME overrides it
    printf "#!/bin/bash\necho 'red'\n" > "${WORKDIR}/bin/dconf"
    chmod +x "${WORKDIR}/bin/dconf"

    FASTFETCH_FORCE_THEME=purple run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "38;2;139;62;165" ]
}

# ---------------------------------------------------------------------------
# Exit behaviour
# ---------------------------------------------------------------------------

@test "ublue-bling-fastfetch: exits 0 on success" {
    FASTFETCH_FORCE_THEME=blue run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "ublue-bling-fastfetch: always prints exactly one line" {
    FASTFETCH_FORCE_THEME=green run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(echo "${output}" | wc -l)" -eq 1 ]
}
