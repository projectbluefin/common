#!/usr/bin/env bats
# Tests for system_files/bluefin/usr/libexec/get-geoclue-latitude
#
# Strategy: mock gdbus, sleep, and command to isolate all D-Bus interaction.
# The script is run directly (not sourced) since it has set -euo pipefail and
# a main flow that cannot be isolated by sourcing.
#
# gdbus mock parses --method and (for Properties.Get) the property name from
# positional args, returning realistic GeoClue2 D-Bus output strings.
#
# Run: bats tests/test_geoclue_latitude.bats

GEOCLUE_SCRIPT="$BATS_TEST_DIRNAME/../system_files/bluefin/usr/libexec/get-geoclue-latitude"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"

    # Mock sleep — no-op so tests don't wait for the poll interval
    printf '#!/bin/bash\nexit 0\n' > "${WORKDIR}/bin/sleep"
    chmod +x "${WORKDIR}/bin/sleep"

    # Default gdbus mock — happy path: northern hemisphere at 45.5°N, 10.0°E
    _write_gdbus_mock "45.5" "10.0"

    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# Write a gdbus mock that returns the given latitude and longitude.
# If lat or lon is the special token "LOCATION_UNAVAILABLE", the Location
# poll never returns a valid path (simulating a timeout scenario after
# patching MAX_ATTEMPTS to 1).
_write_gdbus_mock() {
    local lat="${1}"
    local lon="${2}"

    cat > "${WORKDIR}/bin/gdbus" << MOCK
#!/bin/bash
# Parse --method, --object-path, and trailing positional args
METHOD=""
OBJPATH=""
declare -a EXTRA=()
while [[ \$# -gt 0 ]]; do
    case "\$1" in
        call)               shift ;; # skip the 'call' subcommand
        --system|--session) shift ;;
        --dest)             shift 2 ;;
        --object-path)      OBJPATH="\$2"; shift 2 ;;
        --method)           METHOD="\$2"; shift 2 ;;
        --*)                shift ;;
        *)                  EXTRA+=("\$1"); shift ;;
    esac
done

case "\$METHOD" in
    org.freedesktop.GeoClue2.Manager.CreateClient)
        echo "('/org/freedesktop/GeoClue2/Client/0',)"
        ;;
    org.freedesktop.DBus.Properties.Set | \
    org.freedesktop.GeoClue2.Client.Start | \
    org.freedesktop.GeoClue2.Client.Stop)
        echo "()"
        ;;
    org.freedesktop.DBus.Properties.Get)
        PROP="\${EXTRA[1]:-}"
        case "\$PROP" in
            Location)
                if [[ "${lat}" == "LOCATION_UNAVAILABLE" ]]; then
                    echo "()" # no Location path — triggers timeout
                else
                    echo "('/org/freedesktop/GeoClue2/Location/0',)"
                fi
                ;;
            Latitude)  echo "(<double ${lat}>,)" ;;
            Longitude) echo "(<double ${lon}>,)" ;;
        esac
        ;;
esac
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/gdbus"
}

# Write a gdbus mock that exits non-zero for the given method with an optional
# error message in stderr output.
_write_gdbus_error_mock() {
    local failing_method="${1}"
    local error_msg="${2:-GeoClue2 error}"

    cat > "${WORKDIR}/bin/gdbus" << MOCK
#!/bin/bash
METHOD=""
while [[ \$# -gt 0 ]]; do
    case "\$1" in
        --method) METHOD="\$2"; shift 2 ;;
        *)        shift ;;
    esac
done

if [[ "\$METHOD" == "${failing_method}" ]]; then
    echo "${error_msg}" >&2
    exit 1
fi
# All other methods succeed normally
case "\$METHOD" in
    org.freedesktop.GeoClue2.Manager.CreateClient)
        echo "('/org/freedesktop/GeoClue2/Client/0',)" ;;
    *)
        echo "()" ;;
esac
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/gdbus"
}

# ---------------------------------------------------------------------------
# Happy path — latitude printed to stdout
# ---------------------------------------------------------------------------

@test "geoclue-latitude: prints latitude on success (northern hemisphere)" {
    _write_gdbus_mock "45.5" "10.0"
    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "45.5" ]
}

@test "geoclue-latitude: prints negative latitude for southern hemisphere" {
    _write_gdbus_mock "-33.9" "151.2"
    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "-33.9" ]
}

@test "geoclue-latitude: prints zero-decimal latitude (integer coordinate)" {
    _write_gdbus_mock "51" "0"
    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "51" ]
}

# ---------------------------------------------------------------------------
# gdbus not found
# ---------------------------------------------------------------------------

@test "geoclue-latitude: exits 1 when gdbus is not in PATH" {
    # On systems where /bin is a symlink to /usr/bin (e.g. Fedora/Silverblue),
    # gdbus cannot be reliably excluded from PATH without breaking bash itself.
    # Instead, patch the script to look for a non-existent binary name so that
    # 'command -v' fails and we exercise the same error path.
    PATCHED="${WORKDIR}/get-geoclue-latitude-nogdbus"
    sed 's/command -v gdbus/command -v gdbus_NOTEXIST/' \
        "${GEOCLUE_SCRIPT}" > "${PATCHED}"
    chmod +x "${PATCHED}"

    run bash "${PATCHED}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"gdbus not found"* ]]
}

# ---------------------------------------------------------------------------
# AccessDenied — location services disabled or denied → exit 2
# ---------------------------------------------------------------------------

@test "geoclue-latitude: exits 2 when CreateClient returns AccessDenied" {
    cat > "${WORKDIR}/bin/gdbus" << 'MOCK'
#!/bin/bash
echo "org.freedesktop.DBus.Error.AccessDenied: not allowed" >&2
exit 1
MOCK
    chmod +x "${WORKDIR}/bin/gdbus"

    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"disabled or denied"* ]]
}

@test "geoclue-latitude: exits 2 when Start returns AccessDenied" {
    cat > "${WORKDIR}/bin/gdbus" << 'MOCK'
#!/bin/bash
METHOD=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        call) shift ;;
        --method) METHOD="$2"; shift 2 ;;
        *)        shift ;;
    esac
done

case "$METHOD" in
    org.freedesktop.GeoClue2.Manager.CreateClient)
        echo "('/org/freedesktop/GeoClue2/Client/0',)" ;;
    org.freedesktop.DBus.Properties.Set)
        echo "()" ;;
    org.freedesktop.GeoClue2.Client.Start)
        echo "org.freedesktop.DBus.Error.AccessDenied: denied" >&2
        exit 1 ;;
    *)
        echo "()" ;;
esac
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/gdbus"

    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"disabled or denied"* ]]
}

# ---------------------------------------------------------------------------
# CreateClient fails (non-AccessDenied) → exit 1
# ---------------------------------------------------------------------------

@test "geoclue-latitude: exits 1 when CreateClient fails with generic error" {
    cat > "${WORKDIR}/bin/gdbus" << 'MOCK'
#!/bin/bash
echo "org.freedesktop.DBus.Error.ServiceUnknown: service not found" >&2
exit 1
MOCK
    chmod +x "${WORKDIR}/bin/gdbus"

    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"failed to create"* ]]
}

# ---------------------------------------------------------------------------
# Client path parse failure (CreateClient returns unexpected output) → exit 1
# ---------------------------------------------------------------------------

@test "geoclue-latitude: exits 1 when CreateClient output has no parseable client path" {
    cat > "${WORKDIR}/bin/gdbus" << 'MOCK'
#!/bin/bash
METHOD=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        call) shift ;;
        --method) METHOD="$2"; shift 2 ;;
        *)        shift ;;
    esac
done

case "$METHOD" in
    org.freedesktop.GeoClue2.Manager.CreateClient)
        echo "()" ;;  # missing client path
    *)
        echo "()" ;;
esac
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/gdbus"

    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"failed to parse client path"* ]]
}

# ---------------------------------------------------------------------------
# (0.0, 0.0) coordinates — uninitialized → exit 1
# ---------------------------------------------------------------------------

@test "geoclue-latitude: exits 1 when coordinates are (0.0, 0.0) uninitialized" {
    _write_gdbus_mock "0.0" "0.0"
    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"0.0, 0.0"* ]]
}

@test "geoclue-latitude: exits 1 when coordinates are (0, 0) integer form" {
    _write_gdbus_mock "0" "0"
    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"0.0, 0.0"* ]]
}

# ---------------------------------------------------------------------------
# Latitude parse failure → exit 1
# ---------------------------------------------------------------------------

@test "geoclue-latitude: exits 1 when Latitude gdbus output is unparseable" {
    cat > "${WORKDIR}/bin/gdbus" << 'MOCK'
#!/bin/bash
METHOD=""
OBJPATH=""
declare -a EXTRA=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        call) shift ;; # skip the 'call' subcommand
        --system|--session) shift ;;
        --dest)             shift 2 ;;
        --object-path)      OBJPATH="$2"; shift 2 ;;
        --method)           METHOD="$2"; shift 2 ;;
        --*)                shift ;;
        *)                  EXTRA+=("$1"); shift ;;
    esac
done

case "$METHOD" in
    org.freedesktop.GeoClue2.Manager.CreateClient)
        echo "('/org/freedesktop/GeoClue2/Client/0',)" ;;
    org.freedesktop.DBus.Properties.Set | \
    org.freedesktop.GeoClue2.Client.Start | \
    org.freedesktop.GeoClue2.Client.Stop)
        echo "()" ;;
    org.freedesktop.DBus.Properties.Get)
        PROP="${EXTRA[1]:-}"
        case "$PROP" in
            Location)  echo "('/org/freedesktop/GeoClue2/Location/0',)" ;;
            Latitude)  echo "()" ;;  # empty / unparseable
            Longitude) echo "(<double 10.0>,)" ;;
        esac ;;
esac
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/gdbus"

    run bash "${GEOCLUE_SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"failed to parse latitude"* ]]
}

# ---------------------------------------------------------------------------
# Location poll timeout — no location becomes available → exit 1
#
# Patch MAX_ATTEMPTS to 1 so the loop exits immediately without sleeping.
# ---------------------------------------------------------------------------

@test "geoclue-latitude: exits 1 when location poll times out" {
    # Patch MAX_ATTEMPTS so the loop exits after a single attempt
    PATCHED="${WORKDIR}/get-geoclue-latitude-patched"
    sed 's/LOCATION_TIMEOUT_SECONDS=30/LOCATION_TIMEOUT_SECONDS=0/' \
        "${GEOCLUE_SCRIPT}" > "${PATCHED}"
    chmod +x "${PATCHED}"

    # gdbus never returns a Location path (simulates GeoClue2 not ready)
    cat > "${WORKDIR}/bin/gdbus" << 'MOCK'
#!/bin/bash
METHOD=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        call) shift ;;
        --method) METHOD="$2"; shift 2 ;;
        *)        shift ;;
    esac
done

case "$METHOD" in
    org.freedesktop.GeoClue2.Manager.CreateClient)
        echo "('/org/freedesktop/GeoClue2/Client/0',)" ;;
    org.freedesktop.DBus.Properties.Get)
        echo "()"  ;; # no Location path
    org.freedesktop.GeoClue2.Client.Stop)
        echo "()" ;;
    *)
        echo "()" ;;
esac
exit 0
MOCK
    chmod +x "${WORKDIR}/bin/gdbus"

    run bash "${PATCHED}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"timeout"* ]]
}
