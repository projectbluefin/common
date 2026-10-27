#!/usr/bin/bash

# shellcheck disable=2046
IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
IMAGE_NAME="$(jq -r '.["image-name"]' < "${IMAGE_INFO_FILE}")"
IMAGE_TAG="$(jq -r '.["image-tag"]' < "${IMAGE_INFO_FILE}")"

# The baked image-tag is the compose-time tag; promotion retags the same
# digest, so the followed tag only exists in the booted deployment. Fall back
# to the baked value when no booted ref is available.
BOOTED_TAG="$("${UBLUE_BOOTED_IMAGE_BIN:-/usr/libexec/ublue-booted-image}" tag 2>/dev/null)"
if [[ -n "${BOOTED_TAG}" ]]; then
	IMAGE_TAG="${BOOTED_TAG}"
fi

echo -n "${IMAGE_NAME}:${IMAGE_TAG}"
