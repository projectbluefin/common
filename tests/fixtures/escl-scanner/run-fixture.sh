#!/usr/bin/env bash
#
# Hardware-free eSCL scanner fixture.
#
# Starts the OpenPrinting go-mfp virtual MFP, points a real sane-airscan
# client at it, and asserts that the client detects the scanner and captures
# a deterministic synthetic page. No physical scanner is involved.
#
# Two modes:
#
#   capture  Pin sane-airscan to the simulator's eSCL URL, assert the device
#            is listed by `scanimage -L`, then scan the platen twice and
#            assert both captures are byte-identical PNGs of the expected
#            geometry. This is the acceptance gate.
#
#   dnssd    Bring up dbus + avahi, let the simulator advertise itself over
#            DNS-SD, and assert `airscan-discover` finds it without any
#            hardcoded device URL.
#
# Every external command is overridable through the environment so the
# orchestration logic can be exercised with stubs; see
# tests/test_escl_fixture.bats.
#
# Usage: run-fixture.sh [--mode capture|dnssd] [--port N] [--model FILE]
#                       [--workdir DIR] [--help]

set -euo pipefail

MFP_VIRTUAL=${MFP_VIRTUAL:-mfp-virtual}
SCANIMAGE=${SCANIMAGE:-scanimage}
CURL=${CURL:-curl}
AIRSCAN_DISCOVER=${AIRSCAN_DISCOVER:-airscan-discover}
DBUS_DAEMON=${DBUS_DAEMON:-dbus-daemon}
AVAHI_DAEMON=${AVAHI_DAEMON:-avahi-daemon}

MODE=capture
PORT=${ESCL_FIXTURE_PORT:-50000}
MODEL=${ESCL_FIXTURE_MODEL:-/opt/escl-fixture/models/virtual-escl-scanner.py}
WORKDIR=${ESCL_FIXTURE_WORKDIR:-}
RESOLUTION=${ESCL_FIXTURE_RESOLUTION:-600}
READY_TIMEOUT=${ESCL_FIXTURE_READY_TIMEOUT:-60}
DISCOVERY_TIMEOUT=${ESCL_FIXTURE_DISCOVERY_TIMEOUT:-60}
STOP_TIMEOUT=${ESCL_FIXTURE_STOP_TIMEOUT:-10}

# Name the simulator gives the virtual scanner; it is the SANE device name
# sane-airscan reports and the DNS-SD instance name the model publishes.
DEVICE_NAME='OpenPrinting Virtual MFP'

# Platen geometry from the model, in eSCL's 1/300 inch units. A capture at
# RESOLUTION DPI must have this aspect ratio.
PLATEN_WIDTH=2550
PLATEN_HEIGHT=3508

# A correctly captured page of the go-mfp synthetic test chart compresses to
# far more than this; an empty or truncated capture does not. This is a floor
# against silent truncation, not a content assertion.
MIN_PNG_BYTES=10000

SERVER_PID=''
SERVER_LOG=''
DEVICE=''

log() {
    printf '%s\n' "$*"
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    dump_server_log >&2
    exit 1
}

dump_server_log() {
    [[ -n "$SERVER_LOG" && -s "$SERVER_LOG" ]] || return 0
    printf -- '--- mfp-virtual log (%s) ---\n' "$SERVER_LOG"
    tail -n 50 "$SERVER_LOG"
    printf -- '--- end mfp-virtual log ---\n'
}

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            --mode)
                MODE=${2:-}
                shift 2
                ;;
            --port)
                PORT=${2:-}
                shift 2
                ;;
            --model)
                MODEL=${2:-}
                shift 2
                ;;
            --workdir)
                WORKDIR=${2:-}
                shift 2
                ;;
            --help | -h)
                usage
                exit 0
                ;;
            *)
                printf 'unknown argument: %s\n' "$1" >&2
                usage >&2
                exit 2
                ;;
        esac
    done

    case "$MODE" in
        capture | dnssd) ;;
        *)
            printf 'invalid --mode: %s (expected capture or dnssd)\n' "$MODE" >&2
            exit 2
            ;;
    esac

    [[ "$PORT" =~ ^[0-9]+$ ]] || {
        printf 'invalid --port: %s\n' "$PORT" >&2
        exit 2
    }
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

prepare_workdir() {
    if [[ -z "$WORKDIR" ]]; then
        WORKDIR=$(mktemp -d)
    else
        mkdir -p "$WORKDIR"
    fi
    SERVER_LOG="${WORKDIR}/mfp-virtual.log"
}

start_server() {
    ESCL_FIXTURE_DNSSD="$1" "$MFP_VIRTUAL" -m "$MODEL" -P "$PORT" \
        >"$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
}

# server_running reports whether the simulator is still alive. `kill -0` is
# not enough: an exited child stays a zombie until it is reaped, and the PID
# remains signalable, so the readiness loop would spin until its timeout
# instead of noticing the crash. `jobs -r` lists only running jobs.
server_running() {
    [[ -n "$SERVER_PID" ]] || return 1
    local pid
    for pid in $(jobs -rp); do
        [[ "$pid" == "$SERVER_PID" ]] && return 0
    done
    return 1
}

stop_server() {
    [[ -n "$SERVER_PID" ]] || return 0

    if server_running; then
        kill "$SERVER_PID" 2>/dev/null || true

        local deadline=$((SECONDS + STOP_TIMEOUT))
        while server_running && ((SECONDS < deadline)); do
            sleep 0.2
        done

        # Escalate, so a simulator that ignores SIGTERM cannot hang teardown
        # and leave the CI job waiting on it.
        server_running && kill -KILL "$SERVER_PID" 2>/dev/null
    fi

    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=''
}

cleanup() {
    stop_server
}

wait_for_escl() {
    local url="http://127.0.0.1:${PORT}/eSCL/ScannerCapabilities"
    local deadline=$((SECONDS + READY_TIMEOUT))

    while ((SECONDS < deadline)); do
        if "$CURL" -fsS -o /dev/null --max-time 5 "$url" 2>/dev/null; then
            log "eSCL endpoint is up: ${url}"
            return 0
        fi
        server_running ||
            fail "mfp-virtual exited before ${url} answered"
        sleep 0.5
    done

    fail "${url} did not answer within ${READY_TIMEOUT}s"
}

# detect_device lists scanners through the real SANE frontend and records the
# device name sane-airscan reported, rather than assuming its naming scheme.
detect_device() {
    local listing
    listing=$("$SCANIMAGE" -L 2>&1) || true

    DEVICE=$(
        printf '%s\n' "$listing" |
            sed -n "s/^device .\([^']*\)' is a.*/\1/p" |
            head -n 1
    )

    [[ -n "$DEVICE" ]] || fail "no SANE device reported; scanimage -L said: ${listing}"
    log "sane-airscan reported device: ${DEVICE}"
}

scan() {
    local out=$1
    shift

    "$SCANIMAGE" \
        --device-name "$DEVICE" \
        --format=png \
        "$@" \
        --output-file "$out" \
        >"${out}.log" 2>&1 || {
        cat "${out}.log" >&2
        fail "scanimage failed writing ${out}"
    }

    [[ -s "$out" ]] || fail "scanimage produced an empty capture: ${out}"
}

# png_dimensions validates the PNG signature and prints "WIDTH HEIGHT" read
# from the IHDR chunk, so geometry is checked without an image decoder.
png_dimensions() {
    local file=$1
    local sig

    sig=$(od -An -tx1 -N8 "$file" | tr -d ' \n')
    [[ "$sig" == '89504e470d0a1a0a' ]] || fail "not a PNG file: ${file}"

    od -An -tu4 -j16 -N8 --endian=big "$file"
}

assert_geometry() {
    local file=$1 width=$2 height=$3
    local lhs rhs tol

    ((width > 0 && height > 0)) ||
        fail "capture has no area: ${width}x${height} (${file})"

    # width/height must match the platen aspect ratio to within 1%, which
    # catches a capture that silently fell back to a default scan region.
    lhs=$((width * PLATEN_HEIGHT))
    rhs=$((height * PLATEN_WIDTH))
    tol=$((rhs / 100))

    if ((lhs > rhs + tol || lhs < rhs - tol)); then
        fail "capture ${width}x${height} does not match the platen aspect" \
            "ratio ${PLATEN_WIDTH}:${PLATEN_HEIGHT} (${file})"
    fi
}

assert_size_floor() {
    local file=$1 bytes

    bytes=$(wc -c <"$file")
    ((bytes >= MIN_PNG_BYTES)) ||
        fail "capture is only ${bytes} bytes, below the ${MIN_PNG_BYTES}-byte floor: ${file}"
}

run_capture() {
    local png1="${WORKDIR}/capture-1.png"
    local png2="${WORKDIR}/capture-2.png"
    local dims1 dims2 w1 h1 w2 h2

    # Pin sane-airscan at the fixture instead of relying on DNS-SD multicast.
    # This is what keeps the acceptance gate deterministic in CI; --mode dnssd
    # exercises real discovery separately.
    export SANE_AIRSCAN_DEVICE="escl:${DEVICE_NAME}:http://127.0.0.1:${PORT}/eSCL"

    detect_device

    log "scanning at ${RESOLUTION} DPI, color, platen ..."
    scan "$png1" --resolution "$RESOLUTION" --mode Color
    scan "$png2" --resolution "$RESOLUTION" --mode Color

    cmp -s "$png1" "$png2" ||
        fail "the two captures differ, so the synthetic page is not deterministic" \
            "(${png1} vs ${png2})"

    dims1=$(png_dimensions "$png1")
    dims2=$(png_dimensions "$png2")
    read -r w1 h1 <<<"$dims1"
    read -r w2 h2 <<<"$dims2"

    [[ "$dims1" == "$dims2" ]] ||
        fail "capture geometry is not stable: ${w1}x${h1} vs ${w2}x${h2}"

    assert_geometry "$png1" "$w1" "$h1"
    assert_size_floor "$png1"

    log "OK: deterministic capture ${w1}x${h1} at ${RESOLUTION} DPI"
    log "    ${png1}"
    log "    ${png2}"
}

start_dns_sd_services() {
    # Best effort: inside the fixture container this runs as root and the
    # daemons need these to exist. If it cannot create them the daemon start
    # below fails loudly, so there is nothing to gain from aborting here.
    mkdir -p /run/dbus /run/avahi-daemon 2>/dev/null || true

    if [[ ! -S /run/dbus/system_bus_socket ]]; then
        "$DBUS_DAEMON" --system --fork ||
            fail "could not start the system dbus daemon"
    fi

    "$AVAHI_DAEMON" --daemonize --no-drop-root ||
        fail "could not start avahi-daemon"

    log "dbus and avahi-daemon are up"
}

run_dnssd() {
    local deadline=$((SECONDS + DISCOVERY_TIMEOUT))
    local out=''

    # Discovery must stand on its own: an inherited pin would make this pass
    # without ever exercising DNS-SD.
    unset SANE_AIRSCAN_DEVICE

    while ((SECONDS < deadline)); do
        out=$("$AIRSCAN_DISCOVER" 2>&1) || true

        if printf '%s\n' "$out" | grep -qF "$DEVICE_NAME"; then
            printf '%s\n' "$out"
            log "OK: DNS-SD discovery found ${DEVICE_NAME}"
            return 0
        fi

        sleep 1
    done

    printf '%s\n' "$out" >&2
    dump_avahi_state >&2
    fail "airscan-discover did not find '${DEVICE_NAME}' within ${DISCOVERY_TIMEOUT}s"
}

# dump_avahi_state prints what the daemon actually knows, which is the first
# thing worth seeing when DNS-SD discovery fails.
dump_avahi_state() {
    command -v avahi-browse >/dev/null 2>&1 || return 0
    printf -- '--- avahi-browse -art ---\n'
    timeout 10 avahi-browse -art 2>&1 || true
    printf -- '--- end avahi-browse ---\n'
}

main() {
    parse_args "$@"
    prepare_workdir

    trap cleanup EXIT

    require_cmd "$MFP_VIRTUAL"
    require_cmd "$CURL"
    [[ -f "$MODEL" ]] || fail "model file not found: ${MODEL}"

    if [[ "$MODE" == 'capture' ]]; then
        require_cmd "$SCANIMAGE"
        start_server 0
    else
        require_cmd "$AIRSCAN_DISCOVER"
        require_cmd "$DBUS_DAEMON"
        require_cmd "$AVAHI_DAEMON"
        start_dns_sd_services
        start_server 1
    fi

    wait_for_escl

    case "$MODE" in
        capture) run_capture ;;
        dnssd) run_dnssd ;;
    esac

    log "OK: eSCL fixture passed (mode=${MODE})"
}

main "$@"
