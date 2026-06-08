#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

version-script dynamic-wallpaper user 1 || exit 0

echo "Enabling dynamic wallpaper timer"
systemctl --user enable --now bluefin-dynamic-wallpaper.timer

echo "Setting initial dynamic wallpaper"
/usr/libexec/bluefin-dynamic-wallpaper || true
