#!/usr/bin/env bash

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

SYS_VENDOR="$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null || true)"

# Only run on ASUS hardware
if [[ ! "$SYS_VENDOR" =~ ASUSTeK|ASUS ]]; then
    exit 0
fi

# asusd is installed by the user-setup hook via brew on first login.
# On subsequent boots, enable the system service once it exists.
if ! systemctl list-unit-files asusd.service &>/dev/null; then
    echo "asus-setup: asusd.service not present yet, skipping"
    exit 0
fi

version-script asus system 1 || exit 0

set -x

echo "ASUS hardware detected, enabling system services..."

systemctl enable --now asusd.service asus-shutdown.service || true
udevadm control --reload
udevadm trigger

echo "ASUS system setup complete"
