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

    # Select the correct upstream repo based on image stream. The name/tag ->
    # repo grammar is owned by /usr/libexec/ublue-image-repo; do not restate it.
    IMAGE_NAME="$(jq -r '.["image-name"] // empty' < "${IMAGE_INFO_FILE}")"
    REPO="$("${UBLUE_IMAGE_REPO_BIN:-/usr/libexec/ublue-image-repo}" \
        --default "projectbluefin/bluefin" "$IMAGE_NAME" "$TAG")"

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
