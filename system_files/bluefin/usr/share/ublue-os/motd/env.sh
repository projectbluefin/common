#!/usr/bin/env sh
# KEEP THIS SMALL
# This will run on every shell that a user starts up.

# Get system language (first 2 chars)
export CURRENT_LANG=${LANG:0:2}

# Check if language is available, if not,fallback to English
if ! grep -q "^${CURRENT_LANG}$" lang.list 2>/dev/null; then
    export CURRENT_LANG="en"
fi

export MOTD_IMAGE_NAME="$(jq -rc '."image-ref"' "${MOTD_IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}" | sed 's@ostree-image-signed:docker://@@')"
export MOTD_IMAGE_TAG="$(jq -rc '."image-tag"' "${MOTD_IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}")"
export MOTD_TEMPLATE_FILE="${MOTD_TEMPLATE_FOLDER:-/usr/share/ublue-os/motd/templates/}template-${CURRENT_LANG}.md"
export MOTD_TIP="${MOTD_TIP:-"$(/usr/bin/cat "${MOTD_TIP_DIRECTORY:-/usr/share/ublue-os/motd/tips/}"tips-${CURRENT_LANG}.md 2>/dev/null | shuf -n 1)"}"
