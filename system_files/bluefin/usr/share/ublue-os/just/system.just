# vim: set ft=make :
# This file should only contain bluefin specific stuff

# Configure Bluefin-CLI Terminal Experience with Brew
# Only installs brew packages when enabling bling (not when disabling)
[group('System')]
[no-exit-message]
bluefin-cli:
    #!/usr/bin/env bash
    set -e
    BLING_SRC_DIR="/usr/share/ublue-os/bling"
    BLING_SCRIPT="bling.sh"
    SHELL_NAME="$(basename "${SHELL}")"
    case "${SHELL_NAME}" in
        fish)
            BLING_SCRIPT="bling.fish"
            TARGET_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
            ;;
        zsh)
            TARGET_FILE="${ZDOTDIR:-$HOME}/.zshrc"
            ;;
        bash)
            TARGET_FILE="${HOME}/.bashrc"
            ;;
        *)
            echo "Unknown shell: ${SHELL_NAME}"
            exit 1
            ;;
    esac
    # Check if bling is currently installed before toggling
    BLING_WAS_INSTALLED=1
    if [ -f "${TARGET_FILE}" ] && grep -q "source ${BLING_SRC_DIR}/${BLING_SCRIPT}" "${TARGET_FILE}" 2>/dev/null; then
        BLING_WAS_INSTALLED=0
    fi
    # Toggle bling (ublue-bling will remove if installed, add if not)
    ublue-bling
    # Only install brew packages when enabling (bling was not installed before)
    if [ "${BLING_WAS_INSTALLED}" -ne 0 ]; then
        brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile
    fi

# Set up the VM stack: virt-manager flatpak + QEMU extension (UEFI, TPM, USB passthrough)
[group('System')]
setup-vms:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak install --system --noninteractive flathub \
        org.virt_manager.virt-manager \
        org.virt_manager.virt_manager.Extension.Qemu
    /usr/libexec/ensure-libvirt-session-config
    echo "VM stack ready. Supports: Linux/Windows VMs, Windows 11 (UEFI + TPM), USB passthrough."

# Toggle the VM stack on or off
[group('System')]
toggle-vms:
    #!/usr/bin/env bash
    set -euo pipefail
    if flatpak list --system --columns=application 2>/dev/null | grep -q "org.virt_manager.virt-manager"; then
        gum confirm "Remove the VM stack (virt-manager + QEMU)?" || exit 0
        flatpak uninstall --system --noninteractive \
            org.virt_manager.virt-manager \
            org.virt_manager.virt_manager.Extension.Qemu 2>/dev/null || true
        sed -i '/uri_default.*session/d' "${HOME}/.config/libvirt/libvirt.conf" 2>/dev/null || true
        echo "VM stack removed."
    else
        gum confirm "Install the VM stack (virt-manager + QEMU)?" || exit 0
        just --justfile "{{ justfile() }}" setup-vms
    fi

# Preview Bazaar curated config from a local common checkout
# Usage: ujust bazaar-preview /path/to/common
[group('System')]
bazaar-preview source="{{ invocation_directory() }}":
    #!/usr/bin/env bash
    set -euo pipefail
    SRC_DIR="${source}"
    BAZAAR_DIR="${SRC_DIR}/system_files/bluefin/etc/bazaar"
    for f in bazaar.yaml curated.yaml blocklist.yaml; do
        if [[ ! -f "${BAZAAR_DIR}/${f}" ]]; then
            echo "Missing ${BAZAAR_DIR}/${f}"
            echo "Usage: ujust bazaar-preview /path/to/common"
            exit 1
        fi
    done
    sudo -v
    flatpak info io.github.kolunmi.Bazaar >/dev/null

    BRANDING_DIR="${SRC_DIR}/bluefin-branding/system_files/etc/bazaar"
    if [[ -d "${BRANDING_DIR}" ]]; then
        sudo install -d -m0755 /etc/bazaar
        sudo install -m0644 "${BRANDING_DIR}"/*.jxl /etc/bazaar/
    fi
    sudo install -d -m0755 /etc/bazaar
    sudo install -m0644 "${BAZAAR_DIR}/bazaar.yaml" /etc/bazaar/bazaar.yaml
    sudo install -m0644 "${BAZAAR_DIR}/curated.yaml" /etc/bazaar/curated.yaml
    sudo install -m0644 "${BAZAAR_DIR}/blocklist.yaml" /etc/bazaar/blocklist.yaml
    systemctl --user restart bazaar.service || systemctl --user start bazaar.service || true
    if command -v setsid >/dev/null 2>&1; then
        setsid -f flatpak run io.github.kolunmi.Bazaar >/dev/null 2>&1
    else
        nohup flatpak run io.github.kolunmi.Bazaar >/dev/null 2>&1 &
    fi
    echo "Bazaar preview updated and launched in background."

# Check Secure Boot status and key enrollment
[group('System')]
check-sb-key:
    #!/usr/bin/bash
    echo "== Secure Boot Status =="
    if [ -d /sys/firmware/efi ]; then
        if command -v mokutil &> /dev/null; then
            mokutil --sb-state
        else
            echo "mokutil not available — checking EFI vars..."
            if [ -f /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c ]; then
                SB=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c | awk '{print $NF}')
                [ "$SB" = "1" ] && echo "SecureBoot is enabled" || echo "SecureBoot is disabled"
            else
                echo "Cannot determine Secure Boot status"
            fi
        fi
        echo ""
        echo "== Machine Owner Key (MOK) Status =="
        if command -v mokutil &> /dev/null; then
            mokutil --list-enrolled 2>/dev/null | head -6 || echo "No MOK keys enrolled or mokutil requires sudo"
        fi
        echo ""
        echo "== Kernel Signature =="
        uname -r
        if command -v sbverify &> /dev/null; then
            sbverify --list /boot/vmlinuz-$(uname -r) 2>/dev/null || echo "sbverify not available (install sbsigntools)"
        fi
    else
        echo "Not an EFI system — Secure Boot does not apply."
    fi
