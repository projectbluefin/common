# vim: set ft=make :

# Show the changelog
changelogs:
    #!/usr/bin/bash
    if command -v bctl &>/dev/null; then
        exec bctl changelogs
    fi

    # Get Image Tag from the live system (bootc status), not the build-time
    # image-info.json, which goes stale after a rebase.
    IMAGE_RESOLVE="${IMAGE_RESOLVE:-/usr/libexec/ublue-image-resolve}"
    TAG="$("${IMAGE_RESOLVE}" image-tag || true)"

    # Select the correct upstream repo based on image stream
    IMAGE_NAME="$("${IMAGE_RESOLVE}" image-name || true)"
    if [[ "$IMAGE_NAME" == "dakota" ]]; then
        REPO="projectbluefin/dakota"
    elif [[ "$IMAGE_NAME" =~ ^bluefin-lts ]] || [[ "$TAG" =~ ^lts ]]; then
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
