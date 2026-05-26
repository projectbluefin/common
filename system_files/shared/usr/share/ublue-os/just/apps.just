# vim: set ft=make :

# alias for install-jetbrains-toolbox
[group('Apps')]
jetbrains-toolbox:
    @ujust install-jetbrains-toolbox

# Install JetBrains Toolbox | https://www.jetbrains.com/toolbox-app/
[group('Apps')]
install-jetbrains-toolbox:
    #!/usr/bin/env bash
    brew tap ublue-os/homebrew-tap
    brew install --cask jetbrains-toolbox-linux

# Install OpenTabletDriver, an open source, cross-platform, user-mode tablet driver
[group('Apps')]
install-opentabletdriver:
    #!/usr/bin/bash
    gum confirm --affirmative="Install" --negative="Uninstall" "Installer for OpenTabletDriver"
    EXIT_CODE="$?"

    if [ "${EXIT_CODE}" == 0 ] ; then
      echo "Installing OpenTabletDriver..."

      OTD_TMPDIR="$(mktemp -d)"

      curl -s "https://api.github.com/repos/OpenTabletDriver/OpenTabletDriver/releases/latest" \
        | jq -r '.assets | sort_by(.created_at) | .[] | select (.name|test("opentabletdriver.*tar.gz$")) | .browser_download_url' \
        | wget -qi - -O - \
        | tar --strip-components=1 -xvzf - -C "${OTD_TMPDIR}"

      # https://opentabletdriver.net/Wiki/Documentation/RequiredPermissions
      sudo cp "${OTD_TMPDIR}/etc/udev/rules.d/70-opentabletdriver.rules" /etc/udev/rules.d/71-opentabletdriver.rules
      echo -ne "blacklist hid_uclogic\nblacklist wacom\n" | sudo tee /etc/modprobe.d/blacklist-opentabletdriver.conf
      rm -rf "${OTD_TMPDIR}"

      flatpak --system install -y flathub net.opentabletdriver.OpenTabletDriver

      mkdir -p "$HOME/.config/systemd/user"
      curl -s "https://raw.githubusercontent.com/flathub/net.opentabletdriver.OpenTabletDriver/refs/heads/master/scripts/opentabletdriver.service" > "$HOME/.config/systemd/user/opentabletdriver.service"

      systemctl --user daemon-reload
      systemctl enable --user --now opentabletdriver.service
    elif [ "${EXIT_CODE}" == 1 ] ; then
      echo "Uninstalling OpenTabletDriver..."
      sudo rm -f /etc/modprobe.d/blacklist-opentabletdriver.rules /etc/udev/rules.d/71-opentabletdriver.rules
      flatpak --system remove -y flathub net.opentabletdriver.OpenTabletDriver
    fi

# Install applications from curated Brewfiles (includes full-desktop.Brewfile with GNOME Circle apps)
bbrew:
    #!/usr/bin/env bash
    if ! command -v bbrew &>/dev/null ; then
        if gum confirm "Bold Brew is not installed, would you like to install it?" ; then
            set -e
            brew install Valkyrie00/homebrew-bbrew/bbrew
            set +e
        else
            exit 0
        fi
    fi
    echo "Note: Some of these take a while to load, we'll keep working on it."
    bbrew -f "/usr/share/ublue-os/homebrew/$(gum choose $(find "/usr/share/ublue-os/homebrew"/*.Brewfile -exec basename '{}' '.Brewfile' ';')).Brewfile"

cncf:
    #!/usr/bin/env bash
    if ! command -v bbrew &>/dev/null ; then
        if gum confirm "Bold Brew is not installed, would you like to install it?" ; then
            brew install Valkyrie00/homebrew-bbrew/bbrew
        else
            exit 0
        fi
    fi
    bbrew -f "/usr/share/ublue-os/homebrew/cncf.Brewfile"

dx_justfile := "/usr/share/ublue-os/just/dx.just"
# Override for dev: export DX_LIB=/path/to/dx-install-lib.sh

# dx-next — interactive DX-Next install/update/remove (gum menus).
# Docs: docs/dx-next.md. Implementation: dx/*.sh (source libs in one bash shell).
# Non-interactive: DX_NONINTERACTIVE=1 DX_NEXT_ACTION=install|remove DX_NEXT_CHOICES="Virt Docker"
# Dev checkout: scripts/dx-next-dev.sh sets DX_SHARE / DX_UBLUE_ROOT
dx-next:
    #!/usr/bin/env bash
    set -euo pipefail
    # shellcheck source=/usr/share/ublue-os/dx/dx-ui-lib.sh
    source "${DX_SHARE:-/usr/share/ublue-os/dx}/dx-ui-lib.sh"

    # Non-interactive: DX_NONINTERACTIVE=1 DX_NEXT_ACTION=install|remove DX_NEXT_CHOICES="Virt Docker"
    if [ "${DX_NONINTERACTIVE:-}" = "1" ] && [ "${DX_NEXT_ACTION:-install}" = "remove" ]; then
        source "${DX_REMOVE_LIB:-/usr/share/ublue-os/dx/dx-remove-lib.sh}"
        # shellcheck disable=SC2086
        dx_remove_main ${DX_NEXT_REMOVE_FLAGS:---all}
        exit 0
    fi

    # Check if any part of DX-Next is installed
    # We check for the extension image OR the sysusers config OR the presence of 'code'
    if [ "${DX_NONINTERACTIVE:-}" = "1" ] && [ "${DX_NEXT_ACTION:-install}" = "install" ]; then
        : # skip menus; install CHOICES set below
    elif [ -f /var/lib/extensions/dx-next.raw ] || [ -f /etc/sysusers.d/dx-groups.conf ] || command -v code &>/dev/null; then
        # Partial install: markers present but VS Code CLI and sysext image are both missing
        if ! command -v code &>/dev/null && [ ! -f /var/lib/extensions/dx-next.raw ]; then
            DX_MENU_HEADER="DX-Next installation did not complete. What would you like to do?"
        else
            DX_MENU_HEADER="DX-Next is detected. What would you like to do?"
        fi
        ACTION=$(gum choose "Reinstall/Update" "Remove" "Cancel" --header "$DX_MENU_HEADER")
        if [ "$ACTION" = "Cancel" ] || [ -z "$ACTION" ]; then
            exit 0
        elif [ "$ACTION" = "Remove" ]; then
            MODE=$(gum choose "Remove all (Default)" "Customize" --header "Removal Mode")

            if [ -z "$MODE" ]; then
                exit 0
            elif [ "$MODE" = "Remove all (Default)" ]; then
                echo ""
                # shellcheck source=/usr/share/ublue-os/dx/dx-remove-lib.sh
                source "${DX_REMOVE_LIB:-/usr/share/ublue-os/dx/dx-remove-lib.sh}"
                dx_msg "󱗼 Initiating full removal..."
                dx_remove_all_full
                dx_msg_ok "DX-Next has been fully removed. Please reboot to apply changes."
                exit 0
            else
                clear
                echo ""
                gum style --foreground 242 "  Use <space> to select/deselect, <enter> to confirm"
                CHOICES=$(gum choose --no-limit \
                    --selected="Virt,Docker,DX-Tools,Incus,Cockpit" \
                    --header="--- Select Components to Remove ---" \
                    --cursor.foreground 196 --selected.foreground 196 \
                    "Virt" "Docker" "DX-Tools" "Incus" "Cockpit")

                if [ -z "$CHOICES" ]; then
                    exit 0
                fi

                clear
                REMOVE_FLAGS=""
                if echo "$CHOICES" | grep -q "DX-Tools"; then REMOVE_FLAGS="$REMOVE_FLAGS --tools"; fi
                if echo "$CHOICES" | grep -q "Docker"; then REMOVE_FLAGS="$REMOVE_FLAGS --docker"; fi
                if echo "$CHOICES" | grep -q "Virt"; then REMOVE_FLAGS="$REMOVE_FLAGS --virt"; fi
                if echo "$CHOICES" | grep -q "Incus"; then REMOVE_FLAGS="$REMOVE_FLAGS --incus"; fi
                if echo "$CHOICES" | grep -q "Cockpit"; then REMOVE_FLAGS="$REMOVE_FLAGS --cockpit"; fi

                source "${DX_REMOVE_LIB:-/usr/share/ublue-os/dx/dx-remove-lib.sh}"
                dx_msg "󱗼 Removing selected components..."
                # shellcheck disable=SC2086
                if ! dx_remove_main ${REMOVE_FLAGS}; then
                    dx_msg_warn "Some removal steps reported errors; see messages above."
                fi
                dx_msg_ok "Cleanup complete for selected components."
                exit 0
            fi
        fi
        # Reinstall/Update → fall through to installation mode below
    else
        if ! gum confirm "Enter experimental DX mode?"; then
            exit 0
        fi
    fi

    # Non-interactive (debug/CI): DX_NONINTERACTIVE=1 DX_NEXT_CHOICES="Virt Docker"
    if [ "${DX_NONINTERACTIVE:-}" = "1" ]; then
        CHOICES="${DX_NEXT_CHOICES:-Virt Docker}"
        gum style --foreground 242 "Non-interactive install: $CHOICES"
    else
    gum style \
        --border rounded \
        --border-foreground 212 \
        --padding "0 2" \
        --margin "1 0" \
        "DX-Next Environment Setup" "Please select your installation path."

    MODE=$(gum choose "Default" "Customize" --header "Installation Mode")

    if [ -z "$MODE" ]; then
        gum style --foreground 196 "Setup cancelled."
        exit 0
    fi

    if [ "$MODE" = "Default" ]; then
        CHOICES="Virt Docker DX-Tools"
        gum style --foreground 242 "Proceeding with Default options: $CHOICES"
    else
        echo ""
        gum style --foreground 242 "  Use <space> to select/deselect, <enter> to confirm"
        CHOICES=$(gum choose --no-limit \
            --selected="Virt,Docker,DX-Tools" \
            --header="--- Select Components ---" \
            --cursor.foreground 212 --selected.foreground 212 \
            "Virt" "Docker" "DX-Tools" "Incus" "Cockpit")
    fi

    if [ -z "$CHOICES" ]; then
        gum style --foreground 196 "No options selected. Exiting."
        exit 0
    fi
    fi

    echo ""
    dx_msg "󱗼 Initializing DX-Next environment..."
    dx_acquire_sudo

    # Run all components in this shell so sudo stays on one TTY
    # shellcheck source=/usr/share/ublue-os/dx/dx-install-lib.sh
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_groups
    if [ -f /etc/sysusers.d/dx-groups.conf ]; then
        dx_msg_ok "  DX groups: /etc/sysusers.d/dx-groups.conf present"
    else
        dx_msg_warn "  DX groups: sysusers file missing"
    fi
    for CHOICE in $CHOICES; do
        dx_apply_choice "$CHOICE"
    done

    echo "" >&2
    dx_msg "Install pass finished. Summary above; reboot when ready."
    dx_show_complete_banner
