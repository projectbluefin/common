#!/usr/bin/env bash

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
OEM_DIR="/usr/share/ublue-os/oem"

# Normalize DMI vendor strings to canonical oem/ directory name.
# chassis_vendor covers Framework; sys_vendor covers ASUS.
# Add a case arm + oem/<Name>/ directory to support a new OEM.
CHASSIS_VENDOR=$(cat /sys/devices/virtual/dmi/id/chassis_vendor 2>/dev/null || true)
SYS_VENDOR=$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null || true)
PRODUCT_NAME=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)

case "${CHASSIS_VENDOR}:${SYS_VENDOR}" in
    Framework:*)        VENDOR="Framework" ;;
    *:ASUSTeK*|*:ASUS*) VENDOR="ASUS" ;;
    *)                  exit 0 ;;
esac

[[ -d "${OEM_DIR}/${VENDOR}" ]] || exit 0

# Check brew before version-script-check: if brew is absent on first login we must
# not record completion — the version is only committed once the body succeeds.
if [[ ! -x "${BREW_BIN}" ]]; then
    echo "oem-brew: brew not found, will retry on next login"
    exit 0
fi

set -xeuo pipefail
eval "$("${BREW_BIN}" shellenv)"

if version-script-check "oem-${VENDOR}" user 2; then
    brew bundle --file="${OEM_DIR}/${VENDOR}/packages.Brewfile"

    if [[ "${VENDOR}" == "ASUS" ]]; then
        systemctl --user daemon-reload
        systemctl --user enable --now asusd-user.service || true
    fi

    if [[ -f "${OEM_DIR}/${VENDOR}/logo" ]]; then
        dconf write /org/gnome/shell/extensions/custom-command-list/menuicon-setting \
            "'$(cat "${OEM_DIR}/${VENDOR}/logo")'"
    fi

    # Record success only after brew bundle ran, so a failed install retries on
    # the next login instead of being permanently skipped.
    version-script-commit "oem-${VENDOR}" user 2
fi

# Multi-user Framework wallpaper linking:
# In a multi-user setup with a shared Homebrew prefix (/home/linuxbrew/.linuxbrew),
# users logging in after the first see framework-wallpapers already installed and
# Homebrew does not rerun the cask postflight for secondary accounts.
# Ensure every Framework user has wallpapers linked into their ~/.local/share.
if [[ "${VENDOR}" == "Framework" ]]; then
    CASKROOM_DIR="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}/Caskroom/framework-wallpapers"
    if [[ -d "${CASKROOM_DIR}" ]]; then
        # Find the newest installed version directory
        LATEST_VERSION_DIR=$(find "${CASKROOM_DIR}" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*' | sort -V | tail -n1)
        if [[ -n "${LATEST_VERSION_DIR}" && -d "${LATEST_VERSION_DIR}" ]]; then
            install -d "${HOME}/.local/share/backgrounds/framework"
            install -d "${HOME}/.local/share/gnome-background-properties"
            if [[ -d "${LATEST_VERSION_DIR}/images" ]]; then
                for img in "${LATEST_VERSION_DIR}"/images/*; do
                    [[ -f "${img}" ]] && ln -sfn "${img}" "${HOME}/.local/share/backgrounds/framework/$(basename "${img}")"
                done
            fi
            if [[ -d "${LATEST_VERSION_DIR}/gnome-background-properties" ]]; then
                for prop in "${LATEST_VERSION_DIR}"/gnome-background-properties/*; do
                    [[ -f "${prop}" ]] && ln -sfn "${prop}" "${HOME}/.local/share/gnome-background-properties/$(basename "${prop}")"
                done
            fi
        fi
    fi
fi

if [[ "${VENDOR}" == "Framework" && "${PRODUCT_NAME}" == "Framework Desktop" ]] && \
    [[ -f "${OEM_DIR}/${VENDOR}/51-framework-desktop.conf" ]]; then
    install -d "${HOME}/.config/wireplumber/wireplumber.conf.d"
    install -m 0644 "${OEM_DIR}/${VENDOR}/51-framework-desktop.conf" \
        "${HOME}/.config/wireplumber/wireplumber.conf.d/51-framework-desktop.conf"
fi
