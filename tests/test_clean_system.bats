#!/usr/bin/env bats
# Tests for the clean-system recipe in default.just
#
# Run: bats tests/test_clean_system.bats
#
# The bug this guards against (projectbluefin/common#1456): the preview lists
# only dangling images (--filter dangling=true) while the action ran
# `image prune -af`, which also removes every unused *named* image. A user
# confirming a short dangling-only list could lose toolbox/distrobox bases and
# dev/test images. The preview filter and the prune flags must agree, so this
# test records both and asserts they describe the same (dangling-only) set.

JUST_FILE="$BATS_TEST_DIRNAME/../system_files/shared/usr/share/ublue-os/just/default.just"
WORKDIR=""
MOCKDIR=""

# Extract the bash body from the clean-system recipe: start after the
# "clean-system:" header and shebang, strip the 4-space just indentation, and
# stop at the next recipe header (a line at column 0). Nested (deeper
# indented) lines are kept, only fully blank / indented lines end the recipe.
# The recipe calls the absolute path /usr/bin/podman; normalize it to bare
# `podman` so the PATH mock in setup() is what actually runs.
_extract_script() {
    local out_file="$1"
    awk '
        /^clean-system:/ { found=1; next }
        found && /^    #!\/usr\/bin\/bash/ { next }
        found && /^[^ ]/ { exit }
        found { sub(/^    /, ""); print }
    ' "${JUST_FILE}" | sed 's#/usr/bin/podman#podman#g' > "${out_file}"
}

setup() {
    WORKDIR="$(mktemp -d)"
    MOCKDIR="${WORKDIR}/bin"
    mkdir -p "${MOCKDIR}"

    # Record what the recipe asks podman / docker to do.
    PODMAN_CALLS="${WORKDIR}/podman_calls"
    DOCKER_CALLS="${WORKDIR}/docker_calls"
    touch "${PODMAN_CALLS}" "${DOCKER_CALLS}"
    export PODMAN_CALLS DOCKER_CALLS

    # gum: auto-confirm every prompt (exit 0).
    printf '#!/bin/bash\nexit 0\n' > "${MOCKDIR}/gum"
    chmod +x "${MOCKDIR}/gum"

    # podman: log the full invocation, answer the image ls preview with one
    # fake dangling image so the preview line is non-empty.
    cat > "${MOCKDIR}/podman" <<EOF
#!/bin/bash
echo "podman \$*" >> "\${PODMAN_CALLS}"
case "\$1 \$2" in
    "image ls")
        if [[ "\${MOCK_MANY_CANDIDATES:-0}" == "1" ]]; then
            for i in {1..21}; do echo "podman-image-\${i}"; done
        else
            echo "example.com/base:latest  abc123"
        fi
        exit 0
        ;;
    "volume ls")
        if [[ "\${MOCK_MANY_CANDIDATES:-0}" == "1" ]]; then
            for i in {1..21}; do echo "podman-volume-\${i}"; done
        else
            echo "dangling-volume"
        fi
        exit 0
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "${MOCKDIR}/podman"

    # docker: same shape, logged separately. Present on PATH so the docker
    # branch (command -v docker) is exercised too.
    cat > "${MOCKDIR}/docker" <<EOF
#!/bin/bash
echo "docker \$*" >> "\${DOCKER_CALLS}"
case "\$1 \$2" in
    "image ls")
        if [[ "\${MOCK_MANY_CANDIDATES:-0}" == "1" ]]; then
            for i in {1..21}; do echo "docker-image-\${i}"; done
        else
            echo "example.com/base:latest  abc123"
        fi
        exit 0
        ;;
    "volume ls")
        if [[ "\${MOCK_MANY_CANDIDATES:-0}" == "1" ]]; then
            for i in {1..21}; do echo "docker-volume-\${i}"; done
        else
            echo "dangling-volume"
        fi
        exit 0
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "${MOCKDIR}/docker"

    # Other commands the recipe calls — no-ops on PATH.
    for cmd in flatpak rpm-ostree brew; do
        printf '#!/bin/bash\nexit 0\n' > "${MOCKDIR}/${cmd}"
        chmod +x "${MOCKDIR}/${cmd}"
    done

    export PATH="${MOCKDIR}:${PATH}"

    _extract_script "${WORKDIR}/clean-system.sh"
    chmod +x "${WORKDIR}/clean-system.sh"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "clean-system: podman preview lists only dangling images" {
    bash "${WORKDIR}/clean-system.sh" >/dev/null 2>&1
    grep -q "podman image ls --filter dangling=true" "${PODMAN_CALLS}"
}

@test "clean-system: podman prune removes the dangling-only set (-f, never -a)" {
    bash "${WORKDIR}/clean-system.sh" >/dev/null 2>&1
    grep -q "podman image prune -f" "${PODMAN_CALLS}"
    ! grep -q "podman image prune -a" "${PODMAN_CALLS}"
    ! grep -q "podman image prune -af" "${PODMAN_CALLS}"
}

@test "clean-system: docker preview and prune agree (dangling-only)" {
    bash "${WORKDIR}/clean-system.sh" >/dev/null 2>&1
    grep -q "docker image ls --filter dangling=true" "${DOCKER_CALLS}"
    grep -q "docker image prune -f" "${DOCKER_CALLS}"
    ! grep -q "docker image prune -a" "${DOCKER_CALLS}"
    ! grep -q "docker image prune -af" "${DOCKER_CALLS}"
}

@test "clean-system: preview filter and prune flags cannot drift" {
    bash "${WORKDIR}/clean-system.sh" >/dev/null 2>&1
    # Whatever the preview promises (dangling only), the prune must not remove
    # more: a prune flag of -a/-af against a dangling preview is the drift.
    local prune_flags
    prune_flags="$(grep 'podman image prune' "${PODMAN_CALLS}" | grep -o -- '-[a-f]*' | head -1)"
    [ "${prune_flags}" = "-f" ]
}

@test "clean-system: previews candidates beyond the old 20-row limit" {
    export MOCK_MANY_CANDIDATES=1
    run bash "${WORKDIR}/clean-system.sh"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"podman-image-21"* ]]
    [[ "${output}" == *"podman-volume-21"* ]]
    [[ "${output}" == *"docker-image-21"* ]]
    [[ "${output}" == *"docker-volume-21"* ]]
}
