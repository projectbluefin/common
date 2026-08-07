#!/usr/bin/env bats

DEFAULT_JUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/ublue-os/just/default.just"

_clean_system_recipe() {
    awk '
        /^clean-system:/ { in_recipe=1; next }
        in_recipe && $0 !~ /^    / && $0 !~ /^$/ { exit }
        in_recipe && $0 ~ /^    / { print }
    ' "${DEFAULT_JUST}"
}

@test "clean-system: uses OS-managed Podman binary" {
    local recipe
    recipe="$(_clean_system_recipe)"

    run grep -Fq "/usr/bin/podman image ls" <<< "${recipe}"
    [ "${status}" -eq 0 ]
    run grep -Fq "/usr/bin/podman volume ls" <<< "${recipe}"
    [ "${status}" -eq 0 ]
    run grep -Fq "/usr/bin/podman image prune -af" <<< "${recipe}"
    [ "${status}" -eq 0 ]
    run grep -Fq "/usr/bin/podman volume prune -f" <<< "${recipe}"
    [ "${status}" -eq 0 ]
}

@test "clean-system: does not use unqualified podman" {
    local recipe
    recipe="$(_clean_system_recipe)"

    run grep -Eq '(^|[[:space:]])podman[[:space:]]' <<< "${recipe}"
    [ "${status}" -ne 0 ]
}
