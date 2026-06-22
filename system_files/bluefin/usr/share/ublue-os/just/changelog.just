# vim: set ft=make :

# Show the changelog
changelogs:
    #!/usr/bin/bash
    set -euo pipefail

    # bluefinctl currently maps changelogs by tag alone, which sends Dakota
    # users to Bluefin release notes. Keep ujust variant-aware here until the
    # CLI implementation derives the repo from image-info too.
    if [[ -r /usr/share/ublue-os/changelog.md ]]; then
        exec glow -p /usr/share/ublue-os/changelog.md
    fi

    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    TAG="$(jq -r '.["image-tag"]' < "${IMAGE_INFO_FILE}")"
    IMAGE_REF="$(jq -r '.["image-ref"] // empty' < "${IMAGE_INFO_FILE}")"
    IMAGE_NAME="$(jq -r '.["image-name"] // empty' < "${IMAGE_INFO_FILE}")"
    IMAGE_SOURCE="${IMAGE_REF:-${IMAGE_NAME}}"
    IMAGE_PATH="$(sed -E 's|^.*://||; s|^[a-z-]+:||; s|:.+$||' <<< "${IMAGE_SOURCE}")"
    IMAGE_BASENAME="${IMAGE_PATH##*/}"

    case "${IMAGE_BASENAME}" in
        dakota|dakota-*)
            REPO="projectbluefin/dakota"
            ;;
        bluefin-lts|bluefin-lts-*)
            REPO="projectbluefin/bluefin-lts"
            ;;
        *)
            REPO="projectbluefin/bluefin"
            ;;
    esac

    fetch_release_body() {
        local endpoint="$1"
        curl -fsLS "https://api.github.com/repos/${REPO}/releases/${endpoint}" \
            | jq -r '.body // empty'
    }

    CONTENT=""
    if [[ "$TAG" =~ gts$|stable$|^lts ]]; then
        DATE="$(grep -oP "OSTREE_VERSION=.*\d{2}\.\K\d{8}[.0-9]*" /etc/os-release)"
        if [[ -n "${DATE:-}" ]]; then
            CONTENT="$(curl -fsLS "https://api.github.com/repos/${REPO}/releases" \
                | jq -r ".[] | select(.tag_name==\"${TAG}-${DATE}\") | .body // empty")"
        fi
    fi

    if [[ -z "${CONTENT:-}" ]]; then
        echo "No release-specific notes for ${TAG}; showing the latest ${REPO#projectbluefin/} release notes."
        CONTENT="$(fetch_release_body latest || true)"
    fi

    if [[ -n "${CONTENT:-}" ]]; then
        echo "${CONTENT}" | glow -p
        exit 0
    fi

    echo "WARN: Could not fetch changelog content for ${REPO}."
    exit 1
