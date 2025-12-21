# vim: set ft=make :

# Install recommended GNOME extensions for Bluefin
[group('Apps')]
install-gnome-extensions:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    
    if ! gum confirm "These GNOME extensions are not officially supported but are pretty awesome. Continue?" ; then
        exit 0
    fi
    
    EXTENSIONS=(
        "Battery-Health-Charging@maniacx.github.com"
        "Bluetooth-Battery-Meter@maniacx.github.com"
        "monitor-brightness-volume@ailin.nemui"
        "copyous@boerdereinar.dev"
        "just-perfection-desktop@just-perfection"
        "nightthemeswitcher@romainvigier.fr"
        "quicksettings-audio-devices-hider@marcinjahn.com"
        "quicksettings-audio-devices-renamer@marcinjahn.com"
        "tilingshell@ferrarodomenico.com"
    )
    
    echo "${bold}Installing GNOME Extensions...${normal}"
    GNOME_VERSION=$(gnome-shell --version | cut -d' ' -f3 | cut -d'.' -f1)
    
    for UUID in "${EXTENSIONS[@]}"; do
        echo "Installing ${UUID%%@*}..."
        # URL encode the UUID for the API request
        UUID_ENCODED=$(echo -n "$UUID" | jq -sRr @uri)
        DOWNLOAD_URL=$(curl -s "https://extensions.gnome.org/extension-info/?uuid=${UUID_ENCODED}&shell_version=${GNOME_VERSION}" | jq -r '.download_url')
        
        if [ "$DOWNLOAD_URL" = "null" ] || [ -z "$DOWNLOAD_URL" ]; then
            echo "${red}Failed: ${UUID%%@*}${normal}"
            continue
        fi
        
        curl -sL "https://extensions.gnome.org${DOWNLOAD_URL}" -o /tmp/${UUID}.zip && \
        gnome-extensions install --force /tmp/${UUID}.zip && \
        rm -f /tmp/${UUID}.zip || echo "${red}Failed: ${UUID%%@*}${normal}"
        
        # Enable all except Just Perfection
        [ "$UUID" != "just-perfection-desktop@just-perfection" ] && \
        gnome-extensions enable "$UUID" 2>/dev/null
    done
    
    echo ""
    echo "${bold}Installation complete!${normal}"
    echo "Just Perfection installed but not enabled (configure manually via Extension Manager)."
    echo "${bold}NOTE:${normal} Log out and back in for extensions to fully activate."
