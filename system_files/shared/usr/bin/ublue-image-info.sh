#!/usr/bin/bash

# Resolve from the live system (bootc status) so a rebase is reflected here,
# falling back to the build-time image-info.json inside the resolver.
IMAGE_RESOLVE="${IMAGE_RESOLVE:-/usr/libexec/ublue-image-resolve}"
IMAGE_NAME="$("${IMAGE_RESOLVE}" image-name 2>/dev/null || true)"
IMAGE_TAG="$("${IMAGE_RESOLVE}" image-tag 2>/dev/null || true)"
if [[ -n "${IMAGE_NAME}" || -n "${IMAGE_TAG}" ]]; then
	echo -n "${IMAGE_NAME}:${IMAGE_TAG}"
fi

if [[ "$(rpm-ostree status --booted)" =~ "signed" ]]; then
	echo -n " 🔐"
else
	echo -n -e " \033[5m🔓\033[0m"
fi
