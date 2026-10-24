#!/usr/bin/bash

# shellcheck disable=2046
IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
IMAGE_NAME="$(jq -r '.["image-name"]' < "${IMAGE_INFO_FILE}")"
IMAGE_TAG="$(jq -r '.["image-tag"]' < "${IMAGE_INFO_FILE}")"

# The baked image-tag is always the compose-time tag ("latest");
# promotion retags the same digest, so the followed tag only exists
# in bootc. Fall back to the baked value when bootc is unavailable.
BOOTED_REF="$(bootc status --json 2>/dev/null | \
	jq -r '.status.booted.image.image.image // .spec.image.image // empty' 2>/dev/null)"
BOOTED_IMAGE_FILE="${BOOTED_IMAGE_FILE:-/run/ublue-os/booted-image}"
if [[ -z "${BOOTED_REF}" && -r "${BOOTED_IMAGE_FILE}" ]]; then
	read -r BOOTED_REF < "${BOOTED_IMAGE_FILE}" || true
fi
case "${BOOTED_REF}" in
	*@*) ;; # digest-pinned ref, no tag to extract
	*:*) IMAGE_TAG="${BOOTED_REF##*:}" ;;
esac

echo -n "${IMAGE_NAME}:${IMAGE_TAG}"
