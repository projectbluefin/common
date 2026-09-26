#!/usr/bin/env bash

# shellcheck disable=SC1090,SC1091
LIBSETUP="${LIBSETUP:-/usr/lib/ublue/setup-services/libsetup.sh}"
# SYSROOT: prefix for /sys, /proc, /etc reads — override in tests to use a fake filesystem
SYSROOT="${SYSROOT:-}"
source "${LIBSETUP}"

version-script framework system 3 || exit 0

set -xe

CPU_VENDOR=$(grep "vendor_id" "${SYSROOT}/proc/cpuinfo" | uniq | awk -F": " '{ print $2 }')
VEN_ID="$(cat "${SYSROOT}/sys/devices/virtual/dmi/id/chassis_vendor" 2>/dev/null || true)"
BIOS_VERSION="$(cat "${SYSROOT}/sys/devices/virtual/dmi/id/bios_version" 2>/dev/null || true)"
SYS_ID="$(cat "${SYSROOT}/sys/devices/virtual/dmi/id/product_name" 2>/dev/null || true)"

# Intel Framework hid_sensor_hub karg is obsolete on kernel 6.8+ (brightness keys work natively).
# Blacklisting hid_sensor_hub breaks ambient light sensor (ALS) and causes shutdown on AC unplug.
# Clean up any previously applied karg from rpm-ostree.
if [[ ":Framework:" =~ :$VEN_ID: ]]; then
	if [[ "GenuineIntel" == "$CPU_VENDOR" ]]; then
		if command -v rpm-ostree >/dev/null 2>&1; then
			OSTREE_KARGS=$(rpm-ostree kargs 2>/dev/null || true)
			if [[ $OSTREE_KARGS =~ "module_blacklist=hid_sensor_hub" ]]; then
				echo "Removing obsolete hid_sensor_hub karg via rpm-ostree"
				rpm-ostree kargs --delete-if-present=module_blacklist=hid_sensor_hub || true
			fi
		fi
	fi
fi

# FRAMEWORK 13 FIXES
if [[ "$VEN_ID" == "Framework" && "$SYS_ID" == "Laptop 13 ("* ]]; then
    echo "Framework Laptop 13 detected"

    # 3.5mm audio jack fix: behavior depends on kernel generation.
    # Fedora kernel (bluefin): fix is no longer needed — kernel handles it natively.
    #   Remove the file if a previous version of this script left it.
    # CentOS/RHEL kernel (bluefin-lts): fix is still required on AMD Framework 13.
    #   Ensure the file is present.
    if [[ "AuthenticAMD" == "$CPU_VENDOR" ]]; then
        if grep -q "^ID=fedora" "${SYSROOT}/etc/os-release" 2>/dev/null; then
            if [[ -f "${SYSROOT}/etc/modprobe.d/alsa.conf" ]]; then
                echo "Removing obsolete 3.5mm audio jack fix (Fedora kernel handles this natively)"
                rm -f "${SYSROOT}/etc/modprobe.d/alsa.conf"
            fi
        else
            if [[ ! -f "${SYSROOT}/etc/modprobe.d/alsa.conf" ]]; then
                echo "Applying 3.5mm audio jack fix for non-Fedora kernel"
                echo 'options snd-hda-intel index=1,0 model=auto,dell-headset-multi' \
                    > "${SYSROOT}/etc/modprobe.d/alsa.conf"
            fi
        fi
    fi

    # Suspend fix for Framework 13 Ryzen 7040
    # On BIOS versions >= 3.09, the workaround is not needed
    # (https://knowledgebase.frame.work/framework-laptop-13-bios-and-driver-releases-amd-ryzen-7040-series-r1rXGVL16)
    if [[ "$SYS_ID" == "Laptop 13 (AMD Ryzen 7040Series)" && "$(printf '%s\n' 03.08 "$BIOS_VERSION" | sort -V | tail -n1)" == "03.08" ]]; then
        # BIOS is older, apply workaround
        if [[ ! -f "${SYSROOT}/etc/udev/rules.d/20-suspend-fixes.rules" ]]; then
            echo "Framework 13 Ryzen 7040 with BIOS $BIOS_VERSION < 3.09 — applying suspend workaround"
            echo 'ACTION=="add", SUBSYSTEM=="serio", DRIVERS=="atkbd", ATTR{power/wakeup}="disabled"' \
                > "${SYSROOT}/etc/udev/rules.d/20-suspend-fixes.rules"
        fi
    else
        # BIOS is >= 3.09, remove workaround if present
        # Older versions of this script also mistakenly applied then
        # workaround to Framework 13 Ryzen AI 300. Will get cleaned up here too.
        if [[ -f "${SYSROOT}/etc/udev/rules.d/20-suspend-fixes.rules" ]]; then
            echo "Removing old suspend workaround"
            rm -f "${SYSROOT}/etc/udev/rules.d/20-suspend-fixes.rules"
        fi
    fi
fi

# Record success only after the body ran, so a failing first-boot hook retries
# next boot instead of being permanently skipped.
version-script-commit framework system 3
