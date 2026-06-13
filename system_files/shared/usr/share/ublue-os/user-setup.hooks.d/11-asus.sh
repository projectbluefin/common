#!/usr/bin/env bash

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

SYS_VENDOR="$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null || true)"

# Only run on ASUS hardware
if [[ ! "$SYS_VENDOR" =~ ASUSTeK|ASUS ]]; then
    exit 0
fi

version-script asus user 1 || exit 0

set -xeuo pipefail

BREW_BIN="/var/home/linuxbrew/.linuxbrew/bin/brew"

if [[ ! -x "${BREW_BIN}" ]]; then
    echo "asus-setup: brew not found, skipping ASUS tool install"
    exit 0
fi

eval "$("${BREW_BIN}" shellenv)"

echo "ASUS hardware detected, installing ASUS tools..."

brew tap --trust ublue-os/tap
brew install --cask ublue-os/tap/asusctl-linux
brew install --cask ublue-os/tap/rog-control-center-linux

systemctl --user daemon-reload
systemctl --user enable --now asusd-user.service || true

echo "ASUS user setup complete"
