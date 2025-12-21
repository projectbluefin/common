# vim: set ft=make :

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
