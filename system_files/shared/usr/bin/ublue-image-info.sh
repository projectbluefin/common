#!/usr/bin/bash

# shellcheck disable=2046
IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
echo -n "$(jq -r '"\(.["image-name"]):\(.["image-tag"])"' < "${IMAGE_INFO_FILE}")"

if [[ "$(rpm-ostree status --booted)" =~ "signed" ]]; then
	echo -n " 🔐"
else
	echo -n -e " \033[5m🔓\033[0m"
fi
