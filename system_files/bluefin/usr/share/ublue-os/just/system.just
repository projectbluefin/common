# vim: set ft=make :
# This file should only contain bluefin specific stuff

# Configure Bluefin-CLI Terminal Experience with Brew
# Only installs brew packages when enabling bling (not when disabling)
[group('System')]
[no-exit-message]
bluefin-cli:
    #!/usr/bin/env bash
    if command -v bctl &>/dev/null; then
        exec bctl bluefin-cli
    fi
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

# alias for toggle-devmode — opens the Developer panel in bluefinctl when available
devmode:
    #!/usr/bin/env bash
    if command -v bctl &>/dev/null; then
        exec bctl --screen developer
    fi
    ujust toggle-devmode

# Set up the Developer Experience
[group('System')]
toggle-devmode:
    #!/usr/bin/env bash
    if command -v bctl &>/dev/null; then
        exec bctl devmode --enable
    fi
    set -e
    JUSTFILE="{{ justfile() }}"
    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    DEVMODE_MARKER="${HOME}/.config/bluefin/devmode"

    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 60 --padding "1 4" \
        "Turn on Developer Mode"
    echo ""

    if [ -f "${DEVMODE_MARKER}" ]; then
        gum confirm "Developer mode is already set up. Add more tools?" || exit 0
        echo ""
    fi

    CHOICES="$(gum choose --no-limit \
        --height 22 \
        --selected-prefix "◉  " \
        --unselected-prefix "○  " \
        --cursor "▸  " \
        --selected "  Docker,  Podman Desktop" \
        "── Docker ───────────────────────────────────" \
        "  Docker" \
        "── Podman ───────────────────────────────────" \
        "  Podman Desktop" \
        "── Virtualization ───────────────────────────" \
        "  Virtual Machines (virt-manager + QEMU)" \
        "  Lima (lightweight VMs via KVM)" \
        "  incus (system containers)" \
        "── IDE ──────────────────────────────────────" \
        "  VS Code" \
        "  VSCodium" \
        "  Antigravity" \
        "  Zed" \
        "  JetBrains Toolbox" \
        "── CLI Editors ──────────────────────────────" \
        "  Neovim" \
        "  Helix" \
        "  vim" \
        "  micro" || true)"

    # _dx_wants: test whether a choice was selected
    _dx_wants() { echo "${CHOICES}" | grep -q "$@"; }

    # Build install summary
    WILL_INSTALL=("devcontainer CLI")
    _dx_wants -F "  Docker"       && WILL_INSTALL+=("docker + compose + lazydocker + dive")
    _dx_wants    "Podman Desktop" && WILL_INSTALL+=("Podman Desktop")
    _dx_wants    "Virtual Machines" && WILL_INSTALL+=("virt-manager + QEMU")
    _dx_wants -F "  Lima"         && WILL_INSTALL+=("Lima")
    _dx_wants    "incus"          && WILL_INSTALL+=("incus")
    _dx_wants -F "  VS Code"      && WILL_INSTALL+=("VS Code")
    _dx_wants    "VSCodium"       && WILL_INSTALL+=("VSCodium")
    _dx_wants    "Antigravity"    && WILL_INSTALL+=("Antigravity")
    _dx_wants    "Zed"            && WILL_INSTALL+=("Zed")
    _dx_wants    "JetBrains"      && WILL_INSTALL+=("JetBrains Toolbox")
    _dx_wants    "Neovim"         && WILL_INSTALL+=("Neovim")
    _dx_wants    "Helix"          && WILL_INSTALL+=("Helix")
    _dx_wants -F "  vim"          && WILL_INSTALL+=("vim")
    _dx_wants    "micro"          && WILL_INSTALL+=("micro")

    echo ""
    SUMMARY_BODY=$(
        gum style --bold "Ready to install:"
        for item in "${WILL_INSTALL[@]}"; do
            echo "  ● ${item}"
        done
    )
    gum style \
        --border rounded --border-foreground 212 \
        --padding "1 3" --width 50 \
        "${SUMMARY_BODY}"
    echo ""

    gum confirm "Install now?" || exit 0
    echo ""

    INSTALL_LIBVIRT=0
    INSTALL_LIMA=0
    INSTALL_INCUS=0
    INSTALL_DOCKER=0
    _dx_wants -F "  Docker"       && INSTALL_DOCKER=1
    _dx_wants    "Virtual Machines" && INSTALL_LIBVIRT=1
    _dx_wants -F "  Lima"         && INSTALL_LIMA=1
    _dx_wants    "incus"          && INSTALL_INCUS=1

    # Taps are silent/fast — run before the progress bar
    if _dx_wants -E "VS Code|VSCodium|Antigravity|JetBrains"; then
        brew tap --trust ublue-os/tap
    fi
    if _dx_wants "Zed"; then
        brew tap --trust ublue-os/experimental-tap
    fi

    # Build install queue for the progress bar
    # _dx_add: append one entry to both name and command arrays
    _dx_add() { DX_NAMES+=("$1"); DX_CMDS+=("$2"); }
    DX_NAMES=("devcontainer CLI")
    DX_CMDS=("brew install devcontainer")
    [ "${INSTALL_DOCKER}"  -eq 1 ] && _dx_add "Docker"           "brew install docker docker-compose lazydocker dive"
    _dx_wants    "Podman Desktop" && _dx_add "Podman Desktop"     "flatpak install --system --noninteractive flathub io.podman_desktop.PodmanDesktop"
    [ "${INSTALL_LIBVIRT}" -eq 1 ] && _dx_add "Virtual Machines" "flatpak install --system --noninteractive flathub org.virt_manager.virt-manager org.virt_manager.virt_manager.Extension.Qemu"
    [ "${INSTALL_LIMA}"    -eq 1 ] && _dx_add "Lima"             "brew install lima"
    [ "${INSTALL_INCUS}"   -eq 1 ] && _dx_add "incus"            "brew install incus"
    _dx_wants -F "  VS Code"      && _dx_add "VS Code"           "brew install --cask ublue-os/tap/visual-studio-code-linux"
    _dx_wants    "VSCodium"       && _dx_add "VSCodium"          "brew install --cask ublue-os/tap/vscodium-linux"
    _dx_wants    "Antigravity"    && _dx_add "Antigravity"       "brew install --cask ublue-os/tap/antigravity-linux"
    _dx_wants    "Zed"            && _dx_add "Zed"               "brew install --cask ublue-os/experimental-tap/zed-linux"
    _dx_wants    "JetBrains"      && _dx_add "JetBrains Toolbox" "brew install --cask ublue-os/tap/jetbrains-toolbox-linux"
    _dx_wants    "Neovim"         && _dx_add "Neovim"            "brew install nvim"
    _dx_wants    "Helix"          && _dx_add "Helix"             "brew install helix"
    _dx_wants -F "  vim"          && _dx_add "vim"               "brew install vim"
    _dx_wants    "micro"          && _dx_add "micro"             "brew install micro"

    # Progress bar helpers — Unicode block bar embedded in gum spin title.
    # gum spin clears its own line on success, so we print the checkmark ourselves.
    # Result looks like the Bubble Tea package-manager example:
    #   ✓ devcontainer CLI
    #   ⠙ ████████████░░░░░░░░░░░░░░░░  2/7  Docker
    _dx_bar() {
        local done=$1 total=$2 width=28 bar="" i
        local filled=$(( done * width / total ))
        for ((i=0; i<filled; i++));          do bar+="█"; done
        for ((i=0; i<(width-filled); i++)); do bar+="░"; done
        printf '%s' "${bar}"
    }
    _dx_step() {
        local idx=$1 total=$2 name=$3; shift 3
        local bar; bar="$(_dx_bar "${idx}" "${total}")"
        local digits=${#total} label
        printf -v label "%*d/%*d" "${digits}" "$((idx+1))" "${digits}" "${total}"
        if gum spin --spinner dot \
                --title " ${bar}  ${label}  ${name}" -- "$@"; then
            gum style --foreground 42 "✓ ${name}"
        else
            gum style --foreground 196 "✗ ${name}" >&2
            return 1
        fi
    }

    N=${#DX_NAMES[@]}
    for i in "${!DX_NAMES[@]}"; do
        _dx_step "${i}" "${N}" "${DX_NAMES[${i}]}" \
            bash -c "${DX_CMDS[${i}]}" || exit 1
    done

    # Post-install: configure libvirt session URI (instant — no spinner needed)
    if [ "${INSTALL_LIBVIRT}" -eq 1 ]; then
        /usr/libexec/ensure-libvirt-session-config
    fi

    CURRENT_USER="$(id -un)"
    GROUPS_TO_ADD="dialout"
    [ "${INSTALL_DOCKER}" -eq 1 ]  && GROUPS_TO_ADD="${GROUPS_TO_ADD} docker"
    [ "${INSTALL_LIBVIRT}" -eq 1 ] && GROUPS_TO_ADD="${GROUPS_TO_ADD} libvirt"
    [ "${INSTALL_INCUS}" -eq 1 ]   && GROUPS_TO_ADD="${GROUPS_TO_ADD} incus-admin"
    pkexec bash -c "
        append_group() {
            local g=\"\$1\"
            if ! grep -q \"^\${g}:\" /etc/group 2>/dev/null; then
                grep \"^\${g}:\" /usr/lib/group 2>/dev/null | tee -a /etc/group > /dev/null || true
            fi
        }
        for g in ${GROUPS_TO_ADD}; do
            append_group \"\${g}\"
            usermod -aG \"\${g}\" ${CURRENT_USER} 2>/dev/null || true
        done
    "

    mkdir -p "${HOME}/.config/bluefin"
    touch "${DEVMODE_MARKER}"
    echo ""
    gum style \
        --foreground 2 --border-foreground 2 --border rounded \
        --align center --width 60 --padding "1 4" \
        "Developer Mode is on!  Reboot to apply group changes."

# Configure docker, incus-admin, libvirt, serial permissions (standalone)

# Toggle between the stable and testing image channels
[group('System')]
toggle-testing:
    #!/usr/bin/env bash
    if command -v bctl &>/dev/null; then
        exec bctl toggle-testing
    fi
    set -euo pipefail
    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    IMAGE_TAG="$(jq -r '."image-tag"' < "${IMAGE_INFO_FILE}")"
    IMAGE_REF="$(jq -r '."image-ref"' < "${IMAGE_INFO_FILE}")"
    # Strip transport prefix (ostree-image-signed:docker://, ostree-unverified-registry:, etc.)
    IMAGE_PATH="$(sed -E 's|^.*://||; s|^[a-z-]+:||' <<< "${IMAGE_REF}")"
    if [[ "${IMAGE_TAG}" == *testing* ]]; then
        if [[ "${IMAGE_TAG}" == "testing" ]]; then
            NEW_TAG="stable"
        else
            NEW_TAG="${IMAGE_TAG/-testing/}"
        fi
        gum confirm "Switch from testing to ${NEW_TAG}?" || exit 0
    else
        case "${IMAGE_TAG}" in
            stable|latest) NEW_TAG="testing" ;;
            lts)           NEW_TAG="lts-testing" ;;
            lts-hwe)       NEW_TAG="lts-hwe-testing" ;;
            *)
                echo "Cannot toggle testing from channel '${IMAGE_TAG}'."
                exit 1 ;;
        esac
        echo "Testing images may be unstable and are not recommended for daily use."
        gum confirm "Switch to testing channel (${NEW_TAG})?" || exit 0
    fi
    pkexec bootc switch --enforce-container-sigpolicy "${IMAGE_PATH}:${NEW_TAG}"

# Set up the VM stack: virt-manager flatpak + QEMU extension (UEFI, TPM, USB passthrough)
[group('System')]
setup-vms:
    #!/usr/bin/env bash
    if command -v bctl &>/dev/null; then
        exec bctl setup-vms
    fi
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
    if command -v bctl &>/dev/null; then
        exec bctl toggle-vms
    fi
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

# Install system flatpaks
[group('System')]
install-system-flatpaks $confirm="1":
    #!/usr/bin/env bash
    if command -v bctl &>/dev/null; then
        FLAG=""; [ "$confirm" = "0" ] && FLAG="--yes"
        exec bctl install-system-flatpaks $FLAG
    fi
    if [ "$confirm" != 0 ] ; then
        gum confirm "Install system flatpaks?" || exit 0
    fi
    brew bundle --file="${TARGET_FLATPAK_FILE:-/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile}"

# Install default system flatpaks (alias for install-system-flatpaks)

# For additional applications, run: bctl --screen developer
[group('System')]
bluefin-apps:
    echo "Installing default system flatpaks..."
    @ujust install-system-flatpaks

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

    # Generate PNG banners using podman if they aren't already built on the host
    BRANDING_DIR="${SRC_DIR}/bluefin-branding/system_files/etc/bazaar"
    if [[ -d "${BRANDING_DIR}" ]]; then
        echo "Converting JXL banners to PNG via podman..."
        TMP_PNG_DIR=$(mktemp -d)
        podman run --rm -v "${SRC_DIR}":/workspace:z -v "${TMP_PNG_DIR}":/out:z docker.io/library/alpine:latest sh -c "
            set -e
            apk add -q libjxl-tools &&
            for f in /workspace/bluefin-branding/system_files/etc/bazaar/*.jxl; do
                name=\$(basename \"\$f\" .jxl)
                djxl \"\$f\" \"/out/\${name}.png\" --color_space=sRGB
            done
        "
        sudo install -d -m0755 /etc/bazaar
        sudo install -m0644 "${TMP_PNG_DIR}"/*.png /etc/bazaar/
        rm -rf "${TMP_PNG_DIR}"
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
