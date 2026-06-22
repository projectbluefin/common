#!/usr/bin/env bash

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

BREW_BIN="/var/home/linuxbrew/.linuxbrew/bin/brew"
OEM_DIR="/usr/share/ublue-os/oem"

# Normalize DMI vendor strings to canonical oem/ directory name.
# chassis_vendor covers Framework; sys_vendor covers ASUS.
# Add a case arm + oem/<Name>/ directory to support a new OEM.
CHASSIS_VENDOR=$(cat /sys/devices/virtual/dmi/id/chassis_vendor 2>/dev/null || true)
SYS_VENDOR=$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null || true)

case "${CHASSIS_VENDOR}:${SYS_VENDOR}" in
    Framework:*)        VENDOR="Framework" ;;
    *:ASUSTeK*|*:ASUS*) VENDOR="ASUS" ;;
    *)                  exit 0 ;;
esac

[[ -d "${OEM_DIR}/${VENDOR}" ]] || exit 0

# Check brew before version-script: if brew is absent on first login we must
# not record completion — version-script cannot be undone once it writes.
if [[ ! -x "${BREW_BIN}" ]]; then
    echo "oem-brew: brew not found, will retry on next login"
    exit 0
fi

version-script "oem-${VENDOR}" user 1 || exit 0

set -xeuo pipefail
eval "$("${BREW_BIN}" shellenv)"

brew bundle --file="${OEM_DIR}/${VENDOR}/packages.Brewfile"

if [[ "${VENDOR}" == "ASUS" ]]; then
    systemctl --user daemon-reload
    systemctl --user enable --now asusd-user.service || true
fi

if [[ -f "${OEM_DIR}/${VENDOR}/logo" ]]; then
    dconf write /org/gnome/shell/extensions/custom-command-list/menuicon-setting \
        "'$(cat "${OEM_DIR}/${VENDOR}/logo")'"
fi
