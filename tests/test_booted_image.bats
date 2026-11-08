#!/usr/bin/env bats
# Tests for /usr/libexec/ublue-booted-image — the single reader for the ref,
# name and tag of the booted deployment.

setup() {
    RESOLVER="$BATS_TEST_DIRNAME/../system_files/shared/usr/libexec/ublue-booted-image"
    WORKDIR="$BATS_TEST_DIRNAME/.test_booted_image.$$.$RANDOM"
    mkdir -p "$WORKDIR/bin"
    export RESOLVER WORKDIR
    # Never read the host's boot-time snapshot.
    export UBLUE_BOOTED_IMAGE_FILE="$WORKDIR/booted-image"
}

teardown() {
    rm -rf "$WORKDIR"
}

mock_bootc_json() {
    printf '#!/usr/bin/bash\n[[ "$1" == "status" && "$2" == "--json" ]] || exit 1\nprintf "%%s" %q\n' "$1" \
        > "$WORKDIR/bin/bootc"
    chmod +x "$WORKDIR/bin/bootc"
}

mock_bootc_fails() {
    printf '#!/usr/bin/bash\nexit 1\n' > "$WORKDIR/bin/bootc"
    chmod +x "$WORKDIR/bin/bootc"
}

resolve() {
    run env PATH="$WORKDIR/bin:$PATH" "$RESOLVER" "$@"
}

@test "booted-image: ref defaults to the booted image from bootc" {
    mock_bootc_json '{"status":{"booted":{"image":{"image":{"image":"ghcr.io/projectbluefin/dakota:testing"}}}}}'
    resolve
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/projectbluefin/dakota:testing" ]
}

@test "booted-image: tag and name come from the booted ref" {
    mock_bootc_json '{"status":{"booted":{"image":{"image":{"image":"ghcr.io/projectbluefin/dakota:testing"}}}}}'
    resolve tag
    [ "$status" -eq 0 ]
    [ "$output" = "testing" ]
    resolve name
    [ "$status" -eq 0 ]
    [ "$output" = "dakota" ]
}

@test "booted-image: falls back to spec.image when status.booted is absent" {
    mock_bootc_json '{"spec":{"image":{"image":"ghcr.io/ublue-os/bluefin:stable"}}}'
    resolve ref
    [ "$status" -eq 0 ]
    [ "$output" = "ghcr.io/ublue-os/bluefin:stable" ]
}

@test "booted-image: falls back to the boot-time snapshot when bootc fails" {
    mock_bootc_fails
    printf 'ghcr.io/projectbluefin/dakota:stable\n' > "$UBLUE_BOOTED_IMAGE_FILE"
    resolve tag
    [ "$status" -eq 0 ]
    [ "$output" = "stable" ]
}

@test "booted-image: bootc wins over the boot-time snapshot" {
    mock_bootc_json '{"status":{"booted":{"image":{"image":{"image":"ghcr.io/projectbluefin/dakota:testing"}}}}}'
    printf 'ghcr.io/projectbluefin/dakota:stable\n' > "$UBLUE_BOOTED_IMAGE_FILE"
    resolve tag
    [ "$status" -eq 0 ]
    [ "$output" = "testing" ]
}

@test "booted-image: exits 1 with no output when nothing is booted" {
    mock_bootc_fails
    resolve ref
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "booted-image: a digest-pinned ref has no tag but keeps its name" {
    mock_bootc_json '{"status":{"booted":{"image":{"image":{"image":"ghcr.io/projectbluefin/dakota@sha256:deadbeef"}}}}}'
    resolve tag
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    resolve name
    [ "$status" -eq 0 ]
    [ "$output" = "dakota" ]
}

@test "booted-image: a registry port is not mistaken for the tag in the name" {
    mock_bootc_json '{"status":{"booted":{"image":{"image":{"image":"localhost:5000/bluefin:latest"}}}}}'
    resolve name
    [ "$status" -eq 0 ]
    [ "$output" = "bluefin" ]
    resolve tag
    [ "$status" -eq 0 ]
    [ "$output" = "latest" ]
}

@test "booted-image: an unknown field is a usage error" {
    resolve digest
    [ "$status" -eq 2 ]
}
