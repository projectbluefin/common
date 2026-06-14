#!/usr/bin/env bash
# Assign factory ICC color profiles for Framework 13 and Framework 16 displays.
# colord cannot auto-assign these profiles via EDID matching because the
# DisplayCAL-generated ICC files lack the EDID_model/EDID_md5 metadata tags
# colord uses for automatic binding. This hook runs once in user session
# context (after graphical-session.target) and calls colormgr to bind the
# correct profile to the built-in display.

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

set -euo pipefail

VEN_ID="$(cat /sys/devices/virtual/dmi/id/chassis_vendor 2>/dev/null || true)"
SYS_ID="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)"

# Only Framework Laptop 13 and Laptop 16 ship ICC profiles
if [[ "$VEN_ID" != "Framework" ]]; then
    exit 0
fi

if [[ "$SYS_ID" != *"Laptop 13"* && "$SYS_ID" != *"Laptop 16"* ]]; then
    exit 0
fi

# colormgr is part of the colord package — skip gracefully if absent
if ! command -v colormgr &>/dev/null; then
    echo "framework-color: colormgr not found, skipping ICC profile assignment"
    exit 0
fi

# colord may not be responsive immediately on first login — retry next time
if ! colormgr get-devices &>/dev/null; then
    echo "framework-color: colord not responsive, will retry on next login"
    exit 0
fi

# Select the ICC profile for this model
if [[ "$SYS_ID" == *"Laptop 13"* ]]; then
    ICC_FILE="framework13.icc"
else
    ICC_FILE="framework16.icc"
fi

ICC_PATH="/usr/share/color/icc/colord/${ICC_FILE}"
if [[ ! -f "$ICC_PATH" ]]; then
    echo "framework-color: ICC profile not found at ${ICC_PATH}"
    exit 0
fi

# Find the built-in display device in colord (first display device).
# On GNOME (X11 and Wayland via mutter), the display device ID uses the
# connector name: xrandr-eDP-1 for Framework's built-in panel.
DEVICE_ID=$(colormgr get-devices-by-kind display 2>/dev/null \
    | awk '/Device ID:/ { print $NF; exit }')

if [[ -z "$DEVICE_ID" ]]; then
    echo "framework-color: no display device found in colord, will retry on next login"
    exit 0
fi

# Find the system ICC profile in colord's profile list by filename.
PROFILE_ID=$(colormgr find-profile-by-filename "$ICC_PATH" 2>/dev/null \
    | awk '/Profile ID:/ { print $NF; exit }')

if [[ -z "$PROFILE_ID" ]]; then
    echo "framework-color: profile ${ICC_FILE} not found in colord (may not be imported yet), will retry on next login"
    exit 0
fi

# All preconditions met — stamp and assign
version-script framework-color user 1 || exit 0

set -x

echo "framework-color: assigning ${ICC_FILE} (${PROFILE_ID}) to display ${DEVICE_ID}"
colormgr device-add-profile "$DEVICE_ID" "$PROFILE_ID"
colormgr device-make-profile-default "$DEVICE_ID" "$PROFILE_ID"
echo "framework-color: ICC profile assigned successfully"
