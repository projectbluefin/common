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
        | jq -r '.assets[] | select(.name | test("opentabletdriver.*tar.gz$")) | .browser_download_url' \
        | xargs curl -L -s \
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

# Install CNCF tools from curated Brewfile | run: bctl --screen developer
[group('Apps')]
cncf:
    #!/usr/bin/env bash
    brew bundle --file=/usr/share/ublue-os/homebrew/cncf.Brewfile
    [[ -t 0 ]] && ujust --choose || true

# Install ASUS laptop tools (asusctl daemon + ROG Control Center) | https://gitlab.com/asus-linux/asusctl
[group('Apps')]
install-asus:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing ASUS laptop tools..."
    brew install --cask ublue-os/tap/asusctl-linux
    brew install --cask ublue-os/tap/rog-control-center-linux
    echo ""
    echo "Enabling system services..."
    sudo systemctl enable --now asusd.service asus-shutdown.service
    sudo udevadm control --reload
    sudo udevadm trigger
    echo ""
    echo "Enabling user daemon..."
    systemctl --user daemon-reload
    systemctl --user enable --now asusd-user.service
    echo ""
    echo "ASUS tools installed! Run 'rog-control-center' or find it in your app launcher."
