#!/usr/bin/env bash

# shellcheck disable=SC1090,SC1091
LIBSETUP="${LIBSETUP:-/usr/lib/ublue/setup-services/libsetup.sh}"
# SYSROOT: prefix for /sys reads — override in tests to use a fake filesystem
SYSROOT="${SYSROOT:-}"
source "${LIBSETUP}"

SYS_VENDOR="$(cat "${SYSROOT}/sys/devices/virtual/dmi/id/sys_vendor" 2>/dev/null || true)"

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

version-script-check asus system 1 || exit 0

set -x

echo "ASUS hardware detected, enabling system services..."

# Enable the units separately: only an asusd.service failure is transient (the
# daemon may not be able to start yet), so udev still has to be reloaded and
# only the version commit is skipped, making the hook retry on the next boot.
setup_ok=1
if ! systemctl enable --now asusd.service; then
    echo "asus-setup: failed to enable asusd.service, retrying next boot" >&2
    setup_ok=0
fi

# asus-shutdown.service is optional and permanently absent on some images, so
# a missing unit must not block the version commit — otherwise the hook would
# reload udev and warn on every boot forever.
if systemctl list-unit-files asus-shutdown.service &>/dev/null; then
    if ! systemctl enable --now asus-shutdown.service; then
        echo "asus-setup: failed to enable asus-shutdown.service, retrying next boot" >&2
        setup_ok=0
    fi
else
    echo "asus-setup: asus-shutdown.service not present, skipping it"
fi

udevadm control --reload || setup_ok=0
udevadm trigger || setup_ok=0

if [[ "${setup_ok}" -eq 0 ]]; then
    echo "asus-setup: setup incomplete, not recording the version"
    exit 0
fi

echo "ASUS system setup complete"

# Record success only after every step above succeeded, so a partial run retries
# next boot instead of being permanently skipped (projectbluefin/common#1137).
version-script-commit asus system 1
