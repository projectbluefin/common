#!/usr/bin/env bats
# Tests for system_files/bluefin/usr/libexec/bluefin-dynamic-wallpaper
#
# Strategy: patch the script's two hard-coded absolute paths to temp-dir
# equivalents so tests can run without root and without real GeoClue2 or
# wallpaper files.  Mock gsettings, get-geoclue-latitude, and date via
# a mock-bin directory prepended to PATH.
#
# Run: bats tests/test_dynamic_wallpaper.bats

WALLPAPER_SCRIPT="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/libexec/bluefin-dynamic-wallpaper"
WORKDIR=""
PATCHED_SCRIPT=""
BACKGROUNDS_DIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    BACKGROUNDS_DIR="${WORKDIR}/backgrounds"
    mkdir -p "${WORKDIR}/bin" "${BACKGROUNDS_DIR}"

    # Patch hard-coded paths to use temp-dir equivalents:
    #   /usr/share/backgrounds/bluefin  →  ${BACKGROUNDS_DIR}
    #   /usr/libexec/get-geoclue-latitude  →  ${WORKDIR}/bin/get-geoclue-latitude
    PATCHED_SCRIPT="${WORKDIR}/dynamic_wallpaper"
    sed \
        -e "s|/usr/share/backgrounds/bluefin|${BACKGROUNDS_DIR}|g" \
        -e "s|/usr/libexec/get-geoclue-latitude|${WORKDIR}/bin/get-geoclue-latitude|g" \
        "${WALLPAPER_SCRIPT}" > "${PATCHED_SCRIPT}"
    chmod +x "${PATCHED_SCRIPT}"

    # Create wallpaper XML stubs for all 12 months
    for m in 01 02 03 04 05 06 07 08 09 10 11 12; do
        touch "${BACKGROUNDS_DIR}/${m}-bluefin.xml"
    done

    # Default gsettings mock — returns a valid bluefin wallpaper for both URIs
    cat > "${WORKDIR}/bin/gsettings" << MOCK
#!/bin/bash
if [[ "\$1" == "get" ]]; then
    echo "'file://${BACKGROUNDS_DIR}/06-bluefin.xml'"
elif [[ "\$1" == "set" ]]; then
    echo "gsettings-set: \$*" >> "${WORKDIR}/gsettings.log"
    exit 0
fi
MOCK
    chmod +x "${WORKDIR}/bin/gsettings"

    # Default get-geoclue-latitude mock — northern hemisphere, no error
    printf '#!/bin/bash\necho "45.0"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/get-geoclue-latitude"

    # Default date mock — returns month 06
    printf '#!/bin/bash\necho "06"\n' > "${WORKDIR}/bin/date"
    chmod +x "${WORKDIR}/bin/date"

    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# Early exit — user has a custom (non-bluefin) wallpaper
# ---------------------------------------------------------------------------

@test "dynamic-wallpaper: exits 0 and prints message when user has custom wallpaper" {
    cat > "${WORKDIR}/bin/gsettings" << 'MOCK'
#!/bin/bash
[[ "$1" == "get" ]] && echo "'file:///home/user/my-photo.jpg'" || exit 0
MOCK
    chmod +x "${WORKDIR}/bin/gsettings"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"personal wallpaper"* ]]
}

@test "dynamic-wallpaper: does not call gsettings set when user has custom wallpaper" {
    cat > "${WORKDIR}/bin/gsettings" << 'MOCK'
#!/bin/bash
if [[ "$1" == "get" ]]; then
    echo "'file:///home/user/custom.jpg'"
elif [[ "$1" == "set" ]]; then
    echo "SET_CALLED"
fi
MOCK
    chmod +x "${WORKDIR}/bin/gsettings"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"SET_CALLED"* ]]
}

# ---------------------------------------------------------------------------
# Northern hemisphere — uses current month unchanged
# ---------------------------------------------------------------------------

@test "dynamic-wallpaper: uses current month for northern hemisphere (month 03)" {
    printf '#!/bin/bash\necho "03"\n' > "${WORKDIR}/bin/date"
    printf '#!/bin/bash\necho "51.5"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/date" "${WORKDIR}/bin/get-geoclue-latitude"

    # gsettings get must return a valid bluefin URI for the initial check
    cat > "${WORKDIR}/bin/gsettings" << MOCK
#!/bin/bash
if [[ "\$1" == "get" ]]; then
    echo "'file://${BACKGROUNDS_DIR}/03-bluefin.xml'"
elif [[ "\$1" == "set" ]]; then
    echo "gsettings-set: \$*"
fi
MOCK
    chmod +x "${WORKDIR}/bin/gsettings"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"03"* ]]
    [[ "${output}" == *"north"* ]]
}

# ---------------------------------------------------------------------------
# Southern hemisphere — month is shifted +6 (modulo 12, 1-based)
# ---------------------------------------------------------------------------

@test "dynamic-wallpaper: shifts month +6 for southern hemisphere (Jan → Jul)" {
    printf '#!/bin/bash\necho "01"\n' > "${WORKDIR}/bin/date"
    printf '#!/bin/bash\necho "-33.9"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/date" "${WORKDIR}/bin/get-geoclue-latitude"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"south"* ]]
    [[ "${output}" == *"adjusted month: 7"* ]]
}

@test "dynamic-wallpaper: shifts month +6 for southern hemisphere (Jun → Dec)" {
    printf '#!/bin/bash\necho "06"\n' > "${WORKDIR}/bin/date"
    printf '#!/bin/bash\necho "-33.9"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/date" "${WORKDIR}/bin/get-geoclue-latitude"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"south"* ]]
    [[ "${output}" == *"adjusted month: 12"* ]]
}

@test "dynamic-wallpaper: shifts month +6 for southern hemisphere (Dec → Jun)" {
    printf '#!/bin/bash\necho "12"\n' > "${WORKDIR}/bin/date"
    printf '#!/bin/bash\necho "-33.9"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/date" "${WORKDIR}/bin/get-geoclue-latitude"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"south"* ]]
    [[ "${output}" == *"adjusted month: 6"* ]]
}

@test "dynamic-wallpaper: shifts month +6 for southern hemisphere (Jul → Jan)" {
    printf '#!/bin/bash\necho "07"\n' > "${WORKDIR}/bin/date"
    printf '#!/bin/bash\necho "-33.9"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/date" "${WORKDIR}/bin/get-geoclue-latitude"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"south"* ]]
    [[ "${output}" == *"adjusted month: 1"* ]]
}

# ---------------------------------------------------------------------------
# Geoclue error fallback — defaults to northern hemisphere, exits 0
# ---------------------------------------------------------------------------

@test "dynamic-wallpaper: falls back to northern hemisphere on geoclue general error (exit 1)" {
    printf '#!/bin/bash\necho "error: failed" >&2\nexit 1\n' \
        > "${WORKDIR}/bin/get-geoclue-latitude"
    printf '#!/bin/bash\necho "04"\n' > "${WORKDIR}/bin/date"
    chmod +x "${WORKDIR}/bin/get-geoclue-latitude" "${WORKDIR}/bin/date"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Error getting location"* ]]
    [[ "${output}" == *"northern hemisphere"* ]]
}

@test "dynamic-wallpaper: falls back to northern hemisphere when location services denied (exit 2)" {
    printf '#!/bin/bash\necho "error: denied" >&2\nexit 2\n' \
        > "${WORKDIR}/bin/get-geoclue-latitude"
    printf '#!/bin/bash\necho "04"\n' > "${WORKDIR}/bin/date"
    chmod +x "${WORKDIR}/bin/get-geoclue-latitude" "${WORKDIR}/bin/date"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"disabled or denied"* ]]
    [[ "${output}" == *"northern hemisphere"* ]]
}

# ---------------------------------------------------------------------------
# Invalid latitude format — falls back to northern hemisphere
# ---------------------------------------------------------------------------

@test "dynamic-wallpaper: falls back to northern hemisphere on invalid latitude format" {
    printf '#!/bin/bash\necho "not-a-number"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/get-geoclue-latitude"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Invalid latitude"* ]]
    [[ "${output}" == *"northern hemisphere"* ]]
}

# ---------------------------------------------------------------------------
# Missing wallpaper file — exits 1 with error message
# ---------------------------------------------------------------------------

@test "dynamic-wallpaper: exits 1 when wallpaper file is missing" {
    rm -f "${BACKGROUNDS_DIR}/06-bluefin.xml"
    printf '#!/bin/bash\necho "06"\n' > "${WORKDIR}/bin/date"
    printf '#!/bin/bash\necho "51.5"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/date" "${WORKDIR}/bin/get-geoclue-latitude"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"not found"* ]]
}

# ---------------------------------------------------------------------------
# Month zero-padding — single-digit months must be padded to 2 digits
# ---------------------------------------------------------------------------

@test "dynamic-wallpaper: month 3 is zero-padded to 03 in the wallpaper path" {
    printf '#!/bin/bash\necho "03"\n' > "${WORKDIR}/bin/date"
    printf '#!/bin/bash\necho "51.5"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/date" "${WORKDIR}/bin/get-geoclue-latitude"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"03-bluefin.xml"* ]]
}

@test "dynamic-wallpaper: southern hemisphere month 1 (Jan) is zero-padded to 07 after shift" {
    printf '#!/bin/bash\necho "01"\n' > "${WORKDIR}/bin/date"
    printf '#!/bin/bash\necho "-33.9"\n' > "${WORKDIR}/bin/get-geoclue-latitude"
    chmod +x "${WORKDIR}/bin/date" "${WORKDIR}/bin/get-geoclue-latitude"

    run bash "${PATCHED_SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"07-bluefin.xml"* ]]
}
