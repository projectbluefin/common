#!/usr/bin/env bats
# Acceptance-evidence admission gate. Covers every branch of the gate:
# admit on pass + exact digest, block on missing/failed/stale evidence,
# block on unreadable/invalid evidence, and require an owning repair task
# when a record is blocked.

setup() {
    ADMIT_SCRIPT="$BATS_TEST_DIRNAME/../scripts/admit-evidence.sh"
    WORKDIR="$BATS_TEST_DIRNAME/.admit-evidence-test-${BATS_TEST_NUMBER}-${$}"
    mkdir -p "$WORKDIR"
}

teardown() {
    rm -rf "$WORKDIR"
}

pass_record() {
    # $1 = digest, $2 = optional repair_task
    printf '{"check":"composefs-boot","status":"pass","image_digest":"%s","repair_task":"%s"}' \
        "${1:-sha256:abc}" "${2:-projectbluefin/utah#938}" >"$WORKDIR/evidence.json"
    printf '%s' "$WORKDIR/evidence.json"
}

@test "admits a pass record captured against the exact candidate digest" {
    digest="sha256:abc"
    evidence="$(pass_record "$digest")"

    run "$ADMIT_SCRIPT" "$digest" "$evidence"
    [ "$status" -eq 0 ]
    [ "$output" = "admit: composefs-boot evidence passed for exact candidate \"sha256:abc\"" ]
}

@test "admits when evidence is read from stdin" {
    digest="sha256:abc"

    run bash -c "$ADMIT_SCRIPT '$digest' < '$(pass_record "$digest")'"
    [ "$status" -eq 0 ]
    [[ "$output" == "admit:"* ]]
}

@test "blocks a failed record even when it names a repair task" {
    digest="sha256:abc"
    printf '{"check":"decoder-load","status":"fail","image_digest":"%s","repair_task":"projectbluefin/utah#919"}' \
        "$digest" >"$WORKDIR/fail.json"
    evidence="$WORKDIR/fail.json"

    run "$ADMIT_SCRIPT" "$digest" "$evidence"
    [ "$status" -eq 1 ]
    [[ "$output" == *"status is \"fail\", not pass"* ]]
}

@test "blocks a missing record" {
    digest="sha256:abc"
    printf '{"check":"decoder-load","status":"missing","image_digest":"%s"}' \
        "$digest" >"$WORKDIR/missing.json"

    run "$ADMIT_SCRIPT" "$digest" "$WORKDIR/missing.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"status is \"missing\", not pass"* ]]
}

@test "admits when evidence is piped on stdin" {
    digest="sha256:abc"

    run bash -c "printf '%s' '$(cat "$(pass_record "$digest")")' | '$ADMIT_SCRIPT' '$digest'"
    [ "$status" -eq 0 ]
    [[ "$output" == "admit:"* ]]
}

@test "blocks evidence captured on a different image than the candidate" {
    evidence="$(pass_record "sha256:old")"

    run "$ADMIT_SCRIPT" "sha256:abc" "$evidence"
    [ "$status" -eq 1 ]
    [[ "$output" == *"different image"* ]]
    [[ "$output" == *"sha256:old"* ]]
    [[ "$output" == *"sha256:abc"* ]]
}

@test "blocks when the evidence file is unreadable" {
    run "$ADMIT_SCRIPT" "sha256:abc" "$WORKDIR/does-not-exist.json"
    [ "$status" -eq 1 ]
    [ "$output" = "block: no acceptance evidence captured for this candidate" ]
}

@test "blocks invalid JSON evidence" {
    printf 'not json at all' >"$WORKDIR/bad.json"

    run "$ADMIT_SCRIPT" "sha256:abc" "$WORKDIR/bad.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not valid JSON"* ]]
}

@test "blocks and flags a missing repair task when a record is blocked" {
    digest="sha256:abc"
    printf '{"check":"decoder-load","status":"fail","image_digest":"%s"}' \
        "$digest" >"$WORKDIR/norepair.json"

    run "$ADMIT_SCRIPT" "$digest" "$WORKDIR/norepair.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"names no owning repair task"* ]]
}

@test "errors on missing candidate digest argument" {
    run "$ADMIT_SCRIPT"
    [ "$status" -eq 2 ]
}
