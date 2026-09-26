#!/usr/bin/env bats
#
# Tests for tests/fixtures/escl-scanner/run-fixture.sh.
#
# The container build and the real sane-airscan client are covered by
# .github/workflows/escl-fixture.yml. These tests cover the orchestration and
# assertion logic by replacing the simulator, curl, scanimage and
# airscan-discover with stubs, so they run anywhere without a container
# runtime, a scanner, or the fixture image.

setup() {
    FIXTURE="${BATS_TEST_DIRNAME}/fixtures/escl-scanner/run-fixture.sh"
    STUB_BIN="${BATS_TEST_TMPDIR}/bin"
    STUB_STATE="${BATS_TEST_TMPDIR}/state"
    WORKDIR="${BATS_TEST_TMPDIR}/work"

    mkdir -p "$STUB_BIN" "$STUB_STATE" "$WORKDIR"

    MODEL="${BATS_TEST_TMPDIR}/model.py"
    printf '# stub model\n' >"$MODEL"

    write_stubs

    export STUB_STATE
    export PATH="${STUB_BIN}:${PATH}"

    FIXTURE_ENV=(
        "MFP_VIRTUAL=${STUB_BIN}/mfp-virtual"
        "SCANIMAGE=${STUB_BIN}/scanimage"
        "CURL=${STUB_BIN}/curl"
        "AIRSCAN_DISCOVER=${STUB_BIN}/airscan-discover"
        "DBUS_DAEMON=${STUB_BIN}/dbus-daemon"
        "AVAHI_DAEMON=${STUB_BIN}/avahi-daemon"
        "ESCL_FIXTURE_MODEL=${MODEL}"
        "ESCL_FIXTURE_WORKDIR=${WORKDIR}"
        "ESCL_FIXTURE_READY_TIMEOUT=5"
        "ESCL_FIXTURE_DISCOVERY_TIMEOUT=2"
    )
}

write_stubs() {
    cat >"${STUB_BIN}/mfp-virtual" <<'STUB'
#!/usr/bin/env bash
printf 'stub mfp-virtual args: %s\n' "$*"
printf 'stub mfp-virtual dnssd: %s\n' "${ESCL_FIXTURE_DNSSD:-}"
if [[ "${STUB_MFP_EXIT_IMMEDIATELY:-0}" == "1" ]]; then
    # Delay briefly so the readiness loop gets a liveness check in while the
    # simulator is still up, which is the case the loop has to handle.
    sleep 0.3
    exit 1
fi
# exec, so SIGTERM reaches the sleeping process directly instead of leaving
# the shell waiting on a foreground child.
exec sleep 600
STUB

    cat >"${STUB_BIN}/curl" <<'STUB'
#!/usr/bin/env bash
count_file="${STUB_STATE}/curl.count"
count=0
[[ -f "$count_file" ]] && count=$(cat "$count_file")
count=$((count + 1))
printf '%s' "$count" >"$count_file"
if ((count <= ${STUB_CURL_FAILS:-0})); then
    exit 22
fi
exit 0
STUB

    cat >"${STUB_BIN}/scanimage" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

printf '%s' "${SANE_AIRSCAN_DEVICE:-}" >"${STUB_STATE}/scanimage.airscan_device"
printf '%s\n' "$*" >>"${STUB_STATE}/scanimage.args"

mode=scan
out=''
while (($#)); do
    case "$1" in
        -L | --list-devices)
            mode=list
            shift
            ;;
        --output-file)
            out=$2
            shift 2
            ;;
        *) shift ;;
    esac
done

if [[ "$mode" == 'list' ]]; then
    if [[ "${STUB_SCANIMAGE_NO_DEVICE:-0}" == "1" ]]; then
        printf 'No scanners were identified.\n'
        exit 0
    fi
    printf "device \`airscan:e0:OpenPrinting Virtual MFP' is a OpenPrinting Virtual MFP eSCL scanner\n"
    exit 0
fi

dims="${STUB_SCAN_DIMS:-5100x7016}"
width=${dims%x*}
height=${dims#*x}

vary=''
if [[ "${STUB_SCAN_VARY:-0}" == "1" ]]; then
    n=0
    [[ -f "${STUB_STATE}/scan.count" ]] && n=$(cat "${STUB_STATE}/scan.count")
    n=$((n + 1))
    printf '%s' "$n" >"${STUB_STATE}/scan.count"
    vary="run-${n}"
fi

# Emit a minimal PNG: signature, IHDR with the requested geometry, then an
# arbitrary payload. Only the signature and IHDR are read back.
be32() {
    printf '\\x%02x\\x%02x\\x%02x\\x%02x' \
        $((($1 >> 24) & 255)) $((($1 >> 16) & 255)) \
        $((($1 >> 8) & 255)) $(($1 & 255))
}

{
    printf '\x89PNG\r\n\x1a\n'
    printf '\x00\x00\x00\x0dIHDR'
    printf '%b' "$(be32 "$width")"
    printf '%b' "$(be32 "$height")"
    printf '\x08\x02\x00\x00\x00'
    printf '\x00\x00\x00\x00'
    printf 'stub-page-%s' "$vary"
    head -c "${STUB_SCAN_PAD:-12000}" /dev/zero | tr '\0' 'x'
} >"$out"
STUB

    cat >"${STUB_BIN}/airscan-discover" <<'STUB'
#!/usr/bin/env bash
printf '%s' "${SANE_AIRSCAN_DEVICE:-}" >"${STUB_STATE}/discover.airscan_device"
if [[ "${STUB_DISCOVER_EMPTY:-0}" == "1" ]]; then
    printf '[devices]\n'
    exit 0
fi
printf '[devices]\n\tOpenPrinting Virtual MFP = http://127.0.0.1:50000/eSCL, eSCL\n'
STUB

    printf '#!/usr/bin/env bash\nexit 0\n' >"${STUB_BIN}/dbus-daemon"
    printf '#!/usr/bin/env bash\nexit 0\n' >"${STUB_BIN}/avahi-daemon"

    chmod 0755 "${STUB_BIN}"/*
}

@test "capture mode passes when the client detects the device and captures match" {
    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -eq 0 ]
    [[ "$output" == *"sane-airscan reported device: airscan:e0:OpenPrinting Virtual MFP"* ]]
    [[ "$output" == *"OK: deterministic capture 5100x7016 at 600 DPI"* ]]
    [[ "$output" == *"OK: eSCL fixture passed (mode=capture)"* ]]
}

@test "capture mode pins sane-airscan at the simulator's eSCL URL" {
    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -eq 0 ]
    run cat "${STUB_STATE}/scanimage.airscan_device"
    [ "$output" = "escl:OpenPrinting Virtual MFP:http://127.0.0.1:50000/eSCL" ]
}

@test "capture mode scans the platen in PNG at the fixture resolution" {
    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -eq 0 ]
    run cat "${STUB_STATE}/scanimage.args"
    [[ "$output" == *"--format=png"* ]]
    [[ "$output" == *"--resolution 600"* ]]
    [[ "$output" == *"--mode Color"* ]]
    [ "$(grep -c -- '--output-file' "${STUB_STATE}/scanimage.args")" -eq 2 ]
}

@test "capture mode fails when the client sees no scanner" {
    export STUB_SCANIMAGE_NO_DEVICE=1

    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -ne 0 ]
    [[ "$output" == *"no SANE device reported"* ]]
}

@test "capture mode fails when the two captures differ" {
    export STUB_SCAN_VARY=1

    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -ne 0 ]
    [[ "$output" == *"the two captures differ"* ]]
}

@test "capture mode fails when the capture is not the platen aspect ratio" {
    export STUB_SCAN_DIMS=1000x1000

    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -ne 0 ]
    [[ "$output" == *"does not match the platen aspect ratio 2550:3508"* ]]
}

@test "capture mode fails when the capture is below the size floor" {
    export STUB_SCAN_PAD=16

    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -ne 0 ]
    [[ "$output" == *"below the 10000-byte floor"* ]]
}

@test "capture mode fails when the capture is not a PNG" {
    export STUB_SCAN_DIMS=5100x7016
    export STUB_SCAN_PAD=12000

    # Corrupt the signature the stub writes by pointing scanimage at a stub
    # that emits a PNM instead.
    cat >"${STUB_BIN}/scanimage" <<'STUB'
#!/usr/bin/env bash
out=''
while (($#)); do
    case "$1" in
        -L | --list-devices)
            printf "device \`airscan:e0:OpenPrinting Virtual MFP' is a scanner\n"
            exit 0
            ;;
        --output-file)
            out=$2
            shift 2
            ;;
        *) shift ;;
    esac
done
printf 'P6\n5100 7016\n255\n' >"$out"
head -c 12000 /dev/zero | tr '\0' 'x' >>"$out"
STUB
    chmod 0755 "${STUB_BIN}/scanimage"

    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -ne 0 ]
    [[ "$output" == *"not a PNG file"* ]]
}

@test "capture mode waits for the eSCL endpoint instead of failing on the first refusal" {
    export STUB_CURL_FAILS=3

    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -eq 0 ]
    [[ "$output" == *"eSCL endpoint is up"* ]]
    [ "$(cat "${STUB_STATE}/curl.count")" -eq 4 ]
}

@test "capture mode fails when the eSCL endpoint never answers" {
    export STUB_CURL_FAILS=9999

    run env "${FIXTURE_ENV[@]}" "ESCL_FIXTURE_READY_TIMEOUT=1" "$FIXTURE" --mode capture

    [ "$status" -ne 0 ]
    [[ "$output" == *"did not answer within 1s"* ]]
    [[ "$output" == *"--- mfp-virtual log"* ]]
}

@test "capture mode fails fast when the simulator exits during startup" {
    export STUB_MFP_EXIT_IMMEDIATELY=1
    export STUB_CURL_FAILS=9999

    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -ne 0 ]
    # The liveness check must catch this, not the readiness timeout.
    [[ "$output" == *"mfp-virtual exited before"* ]]
    [[ "$output" != *"did not answer within"* ]]
}

@test "capture mode fails when the model file is missing" {
    run env "${FIXTURE_ENV[@]}" "ESCL_FIXTURE_MODEL=${BATS_TEST_TMPDIR}/absent.py" \
        "$FIXTURE" --mode capture

    [ "$status" -ne 0 ]
    [[ "$output" == *"model file not found"* ]]
}

@test "capture mode fails when a required command is missing" {
    run env "${FIXTURE_ENV[@]}" "SCANIMAGE=${BATS_TEST_TMPDIR}/absent-scanimage" \
        "$FIXTURE" --mode capture

    [ "$status" -ne 0 ]
    [[ "$output" == *"required command not found"* ]]
}

@test "dnssd mode passes when discovery finds the scanner" {
    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode dnssd

    [ "$status" -eq 0 ]
    [[ "$output" == *"OpenPrinting Virtual MFP"* ]]
    [[ "$output" == *"OK: DNS-SD discovery found OpenPrinting Virtual MFP"* ]]
    [[ "$output" == *"OK: eSCL fixture passed (mode=dnssd)"* ]]
}

@test "dnssd mode turns DNS-SD publishing on for the simulator" {
    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode dnssd

    [ "$status" -eq 0 ]
    # The simulator's output goes to its log, not to the fixture's stdout.
    run cat "${WORKDIR}/mfp-virtual.log"
    [[ "$output" == *"stub mfp-virtual dnssd: 1"* ]]
}

@test "capture mode leaves DNS-SD publishing off" {
    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode capture

    [ "$status" -eq 0 ]
    run cat "${WORKDIR}/mfp-virtual.log"
    [[ "$output" == *"stub mfp-virtual dnssd: 0"* ]]
}

@test "dnssd mode does not inherit a pinned device URL" {
    export SANE_AIRSCAN_DEVICE='escl:inherited:http://example.invalid/eSCL'

    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode dnssd

    [ "$status" -eq 0 ]
    run cat "${STUB_STATE}/discover.airscan_device"
    [ -z "$output" ]
}

@test "dnssd mode fails when discovery never finds the scanner" {
    export STUB_DISCOVER_EMPTY=1

    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode dnssd

    [ "$status" -ne 0 ]
    [[ "$output" == *"airscan-discover did not find 'OpenPrinting Virtual MFP'"* ]]
}

@test "an unknown mode is rejected" {
    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --mode nonsense

    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid --mode: nonsense"* ]]
}

@test "an unknown argument is rejected" {
    run env "${FIXTURE_ENV[@]}" "$FIXTURE" --nope

    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown argument: --nope"* ]]
}

@test "--help exits zero and prints usage" {
    run "$FIXTURE" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: run-fixture.sh"* ]]
}
