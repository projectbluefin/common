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
# Experimental DX mode
dx-next:
    #!/usr/bin/env bash
    if ! gum confirm "Enter experimental DX mode?"; then
        exit 0
    fi

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
            "Virt" "Docker" "DX-Tools" "Incus")
    fi

    if [ -z "$CHOICES" ]; then
        gum style --foreground 196 "No options selected. Exiting."
        exit 0
    fi

    gum style --foreground 212 "󱗼 Initializing DX-Next environment..."

    # Always run group setup
    just -f {{dx_justfile}} dx-groups

    # All subchoices
    if echo "$CHOICES" | grep -q "DX-Tools"; then
        just -f {{dx_justfile}} dx-tools
    fi

    if echo "$CHOICES" | grep -q "Docker"; then
        just -f {{dx_justfile}} dx-docker
    fi

    if echo "$CHOICES" | grep -q "Virt"; then
        just -f {{dx_justfile}} dx-virt
    fi

    if echo "$CHOICES" | grep -q "Incus"; then
        just -f {{dx_justfile}} dx-incus
    fi

    # Final Banner
    echo ""
    gum style --border normal --border-foreground 212 \
        "You are now testing the experimental DX mode. Please report any issues to the GitHub, or come talk with us on Discord!
        
    󰙯  https://discord.gg/8RZGC3uFzA
      https://github.com/projectbluefin/common"

    gum style --foreground 220 "⏻ Please reboot to fully apply changes."