# vim: set ft=make :

# Show the changelog
changelogs:
    #!/usr/bin/bash
    if command -v bctl &>/dev/null; then
        exec bctl changelogs
    fi

    # Get Image Tag
    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    TAG="$(jq -r '.["image-tag"]' < "${IMAGE_INFO_FILE}")"

    # Select the correct upstream repo based on image stream
    IMAGE_NAME="$(jq -r '.["image-name"] // empty' < "${IMAGE_INFO_FILE}")"
    if [[ "$IMAGE_NAME" == "dakota" ]]; then
        REPO="projectbluefin/dakota"
    elif [[ "$TAG" =~ ^lts ]]; then
        REPO="projectbluefin/bluefin-lts"
    else
        REPO="projectbluefin/bluefin"
    fi

    # If stable, gts, or lts, fetch from GitHub Releases
    if [[ "$TAG" =~ gts$|stable$|^lts ]]; then
        DATE="$(grep -oP "OSTREE_VERSION=.*\d{2}\.\K\d{8}[.0-9]*" /etc/os-release)"
        CONTENT="$(curl -Ls "https://api.github.com/repos/${REPO}/releases" | jq -r ".[] | select(.tag_name==\"${TAG}-${DATE}\") | .body")"
    fi

    # Display Content with Glow, otherwise fallback to latest release for this repo
    if [[ -n "${CONTENT:-}" ]]; then
        echo "$CONTENT" | glow -p
    else
        echo "WARN: Could not find a release specific to your image"
        curl -Ls "https://api.github.com/repos/${REPO}/releases/latest" | jq -r ".body" | glow -p
    fi
