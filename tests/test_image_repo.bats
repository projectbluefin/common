#!/usr/bin/env bats
# Tests for /usr/libexec/ublue-image-repo — the single source of truth for
# image-name/tag -> upstream GitHub repository routing.

setup() {
    RESOLVER="$BATS_TEST_DIRNAME/../system_files/shared/usr/libexec/ublue-image-repo"
    export RESOLVER
}

@test "image-repo: bluefin latest routes to projectbluefin/bluefin" {
    run "$RESOLVER" bluefin latest
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/bluefin" ]
}

@test "image-repo: bluefin with lts tag routes to bluefin-lts" {
    run "$RESOLVER" bluefin lts-20260601
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/bluefin-lts" ]
}

@test "image-repo: bluefin-lts-hwe routes to bluefin-lts" {
    run "$RESOLVER" bluefin-lts-hwe stable
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/bluefin-lts" ]
}

@test "image-repo: bluefin-nvidia routes to bluefin" {
    run "$RESOLVER" bluefin-nvidia stable
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/bluefin" ]
}

@test "image-repo: dakota routes to projectbluefin/dakota" {
    run "$RESOLVER" dakota latest
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/dakota" ]
}

# Regression: dakota-nvidia is a published image (docs/skills/image-registry.md).
# The changelog call site used an exact `== dakota` match and sent it to
# projectbluefin/bluefin; the resolver must treat every dakota* variant alike.
@test "image-repo: dakota-nvidia routes to projectbluefin/dakota" {
    run "$RESOLVER" dakota-nvidia stable
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/dakota" ]
}

@test "image-repo: unknown image falls back to caller default" {
    run "$RESOLVER" --default projectbluefin/common knuckle latest
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/common" ]

    run "$RESOLVER" --default projectbluefin/bluefin knuckle latest
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/bluefin" ]
}

@test "image-repo: default fallback is projectbluefin/common" {
    run "$RESOLVER" knuckle latest
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/common" ]
}

@test "image-repo: empty image name with lts tag still routes to bluefin-lts" {
    run "$RESOLVER" --default projectbluefin/bluefin "" lts-hwe
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/bluefin-lts" ]
}

@test "image-repo: --default= form is accepted" {
    run "$RESOLVER" --default=projectbluefin/bluefin "" latest
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/bluefin" ]
}

@test "image-repo: reads IMAGE_NAME/IMAGE_TAG from the environment" {
    IMAGE_NAME=dakota-nvidia IMAGE_TAG=stable run "$RESOLVER"
    [ "$status" -eq 0 ]
    [ "$output" = "projectbluefin/dakota" ]
}

# Structural invariant: no consumer may restate the routing grammar inline.
@test "image-repo: consumers do not hardcode upstream repo routing" {
    local root="$BATS_TEST_DIRNAME/.."
    for consumer in \
        "system_files/bluefin/usr/libexec/bonedigger-report" \
        "system_files/bluefin/usr/share/ublue-os/just/changelog.just"
    do
        run grep -c 'projectbluefin/\(bluefin-lts\|dakota\)"' "$root/$consumer"
        [ "$output" = "0" ]
    done
}
