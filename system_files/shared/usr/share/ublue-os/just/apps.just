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

# Experimental DX mode
dx-next:
    #!/usr/bin/env bash
    if ! gum confirm "Enter experimental DX mode?" ; then
        exit 0
    fi

    gum style --foreground 212 "󱗼 Initializing DX-Next environment..."
    brew bundle --file=/usr/share/ublue-os/homebrew/dx-next.Brewfile

    sudo cp /usr/share/ublue-os/dx/units/* /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable brew-containerd
    sudo systemctl enable brew-dockerd

    /home/linuxbrew/.linuxbrew/bin/docker context use default

    current=$(groups "$USER")
    missing=()
    for group in libvirt docker incus-admin; do
        echo "$current" | grep -qw "$group" || missing+=("$group")
    done

    if [ ${#missing[@]} -ne 0 ]; then
        gum format -- "Adding $USER to: **${missing[*]}**"
        gum style --foreground 220 "⏻ Please reboot when the script is finished to apply group changes."
        sudo mkdir -p /etc/sysusers.d/
        for group in "${missing[@]}"; do echo "m $USER $group"; done | sudo tee /etc/sysusers.d/dx-groups.conf > /dev/null
        sudo systemd-sysusers /etc/sysusers.d/dx-groups.conf
    fi
    SOCKET_DIR="/run/libvirt-quadlet"
    echo 'SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664", GROUP="libvirt"' | sudo tee /etc/udev/rules.d/50-spice-usb.rules
    sudo mkdir -p /var/lib/images /var/lib/libvirt-quadlet /etc/libvirt-quadlet "$SOCKET_DIR"
    sudo chmod 775 "$SOCKET_DIR"
    sudo firewall-cmd --permanent --new-zone=libvirt
    sudo firewall-cmd --permanent --zone=libvirt --set-target=ACCEPT
    sudo firewall-cmd --reload

    sudo mkdir -p /etc/containers/systemd/
    sudo mkdir -p /var/lib/libvirt/images/
    sudo cp /usr/share/ublue-os/dx/quadlets/* /etc/containers/systemd/
    sudo systemctl daemon-reload
    sudo systemctl start libvirt-quadlet

    gum style --foreground 39 "  Incus is available, but not started by default."
    gum format -- "Use \`systemctl start incus-quadlet\` to start it."

    gum style --border normal --border-foreground 212 \
        "You are now testing the experimental DX mode. Please report any issues to the GitHub, or come talk with us on Discord!
        
    󰙯  https://discord.gg/8RZGC3uFzA
      https://github.com/projectbluefin/common"

     flatpak override --user --filesystem=/run/libvirt-quadlet org.virt_manager.VirtManager
     flatpak run org.virt_manager.virt-manager -c "qemu:///system?socket=/run/libvirt-quadlet/libvirt-sock"
