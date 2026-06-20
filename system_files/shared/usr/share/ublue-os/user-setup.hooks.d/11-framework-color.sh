#!/usr/bin/env bash
# Framework display ICC color profile assignment via colormgr
# Assigns factory ICC profiles to Framework 13 and 16 internal displays
# Version history:
#   1 — initial: assign framework13.icc / framework16.icc to internal display

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

VEN_ID="$(cat /sys/devices/virtual/dmi/id/chassis_vendor)"
SYS_ID="$(cat /sys/devices/virtual/dmi/id/product_name)"

# Only run on Framework hardware
if [[ ! ":Framework:" =~ :$VEN_ID: ]]; then
	exit 0
fi

# Determine model and ICC file
if [[ $SYS_ID == "Laptop 16"* ]]; then
	MODEL="16"
	ICC_FILE="/usr/share/color/icc/colord/framework16.icc"
elif [[ $SYS_ID == "Laptop ("* ]] || [[ $SYS_ID == "Laptop 13"* ]]; then
	MODEL="13"
	ICC_FILE="/usr/share/color/icc/colord/framework13.icc"
else
	echo "framework-color: unknown Framework model '$SYS_ID', skipping"
	exit 0
fi

set -euo pipefail

# Check all preconditions BEFORE version-script; exit 0 (retry) on any transient failure
# so the stamp slot is never burned before we know the assignment will succeed.

# colord must be running
if ! systemctl --user is-active colord.service &>/dev/null 2>&1; then
	echo "framework-color: colord not active, will retry next login"
	exit 0
fi

# Get the internal display device ID — exit 0 (retry) if none found (lid closed, headless)
DEVICE_ID=$(colormgr get-devices-by-kind display 2>/dev/null | awk '/Device ID:/ { print $NF; exit }')
if [[ -z "$DEVICE_ID" ]]; then
	echo "framework-color: no display device found, will retry next login"
	exit 0
fi

# Resolve the ICC profile registered with colord
PROFILE_ID=$(colormgr find-profile-by-filename "$ICC_FILE" 2>/dev/null | awk '/Profile ID:/ { print $NF; exit }')
if [[ -z "$PROFILE_ID" ]]; then
	echo "framework-color: ICC profile not registered with colord yet, will retry next login"
	exit 0
fi

# All preconditions met — stamp now so we don't repeat on next login
version-script "framework-color-${MODEL}" user 1 || exit 0

set -x

echo "Assigning Framework ${MODEL} ICC profile to display ${DEVICE_ID}"
colormgr device-add-profile "$DEVICE_ID" "$PROFILE_ID" || true
colormgr device-make-profile-default "$DEVICE_ID" "$PROFILE_ID"

echo "framework-color: ICC profile assigned successfully"
