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
    source /usr/lib/ujust/ujust.sh
    echo "Installer for OpenTabletDriver..."
    echo "${bold}Install or Remove OpenTabletDriver${normal}"
    OPTION=$(Choose "Install" "Uninstall" "Exit")
    if [[ "${OPTION,,}" =~ ^install ]]; then
        echo "Installing OpenTabletDriver..."
        curl -s https://api.github.com/repos/OpenTabletDriver/OpenTabletDriver/releases/latest \
        | jq -r '.assets | sort_by(.created_at) | .[] | select (.name|test("opentabletdriver.*tar.gz$")) | .browser_download_url' \
        | wget -qi - -O /tmp/OpenTabletDriver/opentabletdriver.tar.gz && \
        tar --strip-components=1 -xvzf /tmp/OpenTabletDriver/opentabletdriver.tar.gz -C /tmp/OpenTabletDriver && \
        pkexec cp /tmp/OpenTabletDriver/etc/udev/rules.d/70-opentabletdriver.rules /etc/udev/rules.d/71-opentabletdriver.rules && \
        rm -rf /tmp/OpenTabletDriver && \
        rpm-ostree kargs --append-if-missing=modprobe.blacklist=hid_uclogic --append-if-missing=modprobe.blacklist=wacom && \
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && \
        flatpak --system install -y flathub net.opentabletdriver.OpenTabletDriver && \
        mkdir -p $HOME/.config/OpenTabletDriver && \
        flatpak override --user --filesystem=xdg-config/OpenTabletDriver net.opentabletdriver.OpenTabletDriver && \
        mkdir -p $HOME/.config/systemd/user && \
        curl -s https://raw.githubusercontent.com/flathub/net.opentabletdriver.OpenTabletDriver/refs/heads/master/scripts/opentabletdriver.service > $HOME/.config/systemd/user/opentabletdriver.service  && \
        systemctl --user daemon-reload && \
        systemctl enable --user --now opentabletdriver.service
    elif [[ "${OPTION,,}" =~ ^uninstall ]]; then
        echo "Uninstalling OpenTabletDriver..."
        pkexec rm /etc/udev/rules.d/71-opentabletdriver.rules && \
        rpm-ostree kargs --delete-if-present=modprobe.blacklist=hid_uclogic --delete-if-present=modprobe.blacklist=wacom && \
        flatpak --system remove -y flathub net.opentabletdriver.OpenTabletDriver
    else
        echo "Have a good day :)!"
    fi

# Install applications from curated Brewfiles (includes full-desktop.Brewfile with GNOME Circle apps)
bbrew:
    #!/usr/bin/env bash
    if ! command -v bbrew &>/dev/null ; then
        if gum confirm "Bold Brew is not installed, would you like to install it?" ; then
            brew install Valkyrie00/homebrew-bbrew/bbrew
        else
            exit 0
        fi
    fi
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

# Install recommended GNOME extensions for Bluefin
[group('Apps')]
install-gnome-extensions:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    
    # Confirmation dialog about best-effort support
    if ! gum confirm "These GNOME extensions are not officially supported but are pretty awesome. Continue?" ; then
        exit 0
    fi
    
    # Extension UUIDs and names
    declare -A EXTENSIONS=(
        ["Battery-Health-Charging@maniacx.github.com"]="Battery Health Charging"
        ["Bluetooth-Battery-Meter@maniacx.github.com"]="Bluetooth Battery Meter"
        ["monitor-brightness-volume@ailin.nemui"]="Monitor Brightness/DDC Control"
        ["copyous@boerdereinar.dev"]="Copyous"
        ["just-perfection-desktop@just-perfection"]="Just Perfection"
        ["nightthemeswitcher@romainvigier.fr"]="Night Theme Switcher"
        ["quicksettings-audio-devices-hider@marcinjahn.com"]="Quick Settings Audio Devices Hider"
        ["quicksettings-audio-devices-renamer@marcinjahn.com"]="Quick Settings Audio Devices Renamer"
        ["tilingshell@ferrarodomenico.com"]="Tiling Shell"
    )
    
    # Extension to skip enabling (installed but not enabled)
    SKIP_ENABLE="just-perfection-desktop@just-perfection"
    
    echo "${bold}Installing GNOME Extensions...${normal}"
    mkdir -p /tmp/gnome-extensions
    
    # Get GNOME Shell version for compatibility
    GNOME_VERSION=$(gnome-shell --version | sed 's/[^0-9.]*\([0-9]*\).*/\1/')
    
    for UUID in "${!EXTENSIONS[@]}"; do
        NAME="${EXTENSIONS[$UUID]}"
        echo "Installing ${NAME}..."
        
        # Download extension info to get download URL
        curl -s "https://extensions.gnome.org/extension-info/?uuid=${UUID}&shell_version=${GNOME_VERSION}" > /tmp/gnome-extensions/${UUID}.json
        
        # Extract download URL
        DOWNLOAD_URL=$(jq -r '.download_url' /tmp/gnome-extensions/${UUID}.json 2>/dev/null)
        
        if [ "$DOWNLOAD_URL" = "null" ] || [ -z "$DOWNLOAD_URL" ]; then
            echo "${red}Failed to get download URL for ${NAME}${normal}"
            continue
        fi
        
        # Download and install extension
        curl -s "https://extensions.gnome.org${DOWNLOAD_URL}" -o /tmp/gnome-extensions/${UUID}.zip && \
        gnome-extensions install --force /tmp/gnome-extensions/${UUID}.zip || \
        echo "${red}Failed to install ${NAME}${normal}"
        
        # Enable extension (except Just Perfection)
        if [ "$UUID" != "$SKIP_ENABLE" ]; then
            gnome-extensions enable "$UUID" || echo "${red}Failed to enable ${NAME}${normal}"
        fi
    done
    
    # Cleanup
    rm -rf /tmp/gnome-extensions
    
    echo ""
    echo "${bold}Installation complete!${normal}"
    echo "Just Perfection has been installed but not enabled (configure manually via Extension Manager)."
    echo ""
    echo "${bold}NOTE:${normal} You need to log out and log back in for extensions to fully activate."

