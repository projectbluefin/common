#!/usr/bin/env bash

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

version-script theming user 2 || exit 0

set -xeuo pipefail

VEN_ID="$(cat /sys/devices/virtual/dmi/id/chassis_vendor)"
SYS_ID="$(cat /sys/devices/virtual/dmi/id/product_name)"

if [[ ":Framework:" =~ :$VEN_ID: ]]; then
	echo 'Setting touch scroll type'
	dconf write /org/gnome/desktop/peripherals/mouse/natural-scroll true
	if [[ $SYS_ID == "Laptop ("* ]]; then
		echo 'Applying font fix for Framework 13'
		dconf write /org/gnome/desktop/interface/text-scaling-factor 1.25
	fi
fi

if [[ ":Thelio Astra:" =~ :$SYS_ID: ]]; then
	echo 'Setting Ampere Logo'
	dconf write /org/gnome/shell/extensions/custom-command-list/menuicon-setting "'ampere-logo-symbolic'"
fi
