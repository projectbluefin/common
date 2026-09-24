# vim: set ft=make :

# alias for install-jetbrains-toolbox
[group('Apps')]
jetbrains-toolbox:
    @ujust install-jetbrains-toolbox

# Install JetBrains Toolbox | https://www.jetbrains.com/toolbox-app/
[group('Apps')]
install-jetbrains-toolbox:
    #!/usr/bin/env bash
    brew tap ublue-os/tap 2>/dev/null || true
    brew trust ublue-os/tap 2>/dev/null || true
    brew install --cask ublue-os/tap/jetbrains-toolbox-linux

# Install OpenTabletDriver, an open source, cross-platform, user-mode tablet driver
#
# Supply-chain pins (projectbluefin/common#1170) — update together on a bump:
# - OTD_RELEASE: the upstream release tag; Renovate keeps it current via a
#   custom regex manager in .github/renovate.json5. The tarball filename is
#   derived from it, so the URL stays consistent.
# - OTD_TARBALL_SHA256 / OTD_SERVICE_SHA256: sha256 of the release tarball
#   (GitHub shows it on the release asset as the "sha256:" digest) and of the
#   pinned systemd unit. Renovate does NOT manage these — update them
#   manually in the same PR (sha256sum the new asset and raw unit file).
# - the systemd unit URL is pinned to a fixed flathub packaging commit.
[group('Apps')]
install-opentabletdriver:
    #!/usr/bin/bash
    set -euo pipefail
    EXIT_CODE=0
    gum confirm --affirmative="Install" --negative="Uninstall" "Installer for OpenTabletDriver" || EXIT_CODE=$?

    if [ "${EXIT_CODE}" == 0 ] ; then
      echo "Installing OpenTabletDriver..."

      OTD_TMPDIR="$(mktemp -d)"

      # Tag + sha256 pinned; upstream publishes no separate checksum asset.
      OTD_RELEASE="v0.6.7"
      OTD_TARBALL_SHA256="ab3ecfed8579864d947b2ad04c236822a109bc7c52519af7aaa36e03e99d2265"
      OTD_TARBALL_URL="https://github.com/OpenTabletDriver/OpenTabletDriver/releases/download/${OTD_RELEASE}/opentabletdriver-${OTD_RELEASE#v}_linux-x64_simple.tar.gz"
      curl -fsSL "${OTD_TARBALL_URL}" \
        -o "${OTD_TMPDIR}/otd.tar.gz"
      echo "${OTD_TARBALL_SHA256}  ${OTD_TMPDIR}/otd.tar.gz" | sha256sum -c -
      tar --strip-components=1 -xzf "${OTD_TMPDIR}/otd.tar.gz" -C "${OTD_TMPDIR}"

      # https://opentabletdriver.net/Wiki/Documentation/RequiredPermissions
      # The simple-package tarball keeps the rules file at its archive root.
      sudo cp "${OTD_TMPDIR}/70-opentabletdriver.rules" /etc/udev/rules.d/71-opentabletdriver.rules
      echo -ne "blacklist hid_uclogic\nblacklist wacom\n" | sudo tee /etc/modprobe.d/blacklist-opentabletdriver.conf
      rm -rf "${OTD_TMPDIR}"

      flatpak --system install -y flathub net.opentabletdriver.OpenTabletDriver

      mkdir -p "$HOME/.config/systemd/user"
      # Pinned to a fixed flathub commit; a moving branch ref would let the
      # installed unit change silently at any time (projectbluefin/common#1170).
      OTD_SERVICE_URL="https://raw.githubusercontent.com/flathub/net.opentabletdriver.OpenTabletDriver/1a2a2083b8ed831df3b8b6ae3ddfe7dc21d02e01/scripts/opentabletdriver.service"
      OTD_SERVICE_SHA256="ef2f5c450ed1b30cd143285ee119f3cd89fc7b00e1a62ffe471dc4bdd0a1260a"
      curl -fsSL "${OTD_SERVICE_URL}" -o "$HOME/.config/systemd/user/opentabletdriver.service"
      echo "${OTD_SERVICE_SHA256}  $HOME/.config/systemd/user/opentabletdriver.service" | sha256sum -c -

      systemctl --user daemon-reload
      systemctl enable --user --now opentabletdriver.service
    elif [ "${EXIT_CODE}" == 1 ] ; then
      echo "Uninstalling OpenTabletDriver..."
      sudo rm -f /etc/modprobe.d/blacklist-opentabletdriver.conf /etc/udev/rules.d/71-opentabletdriver.rules
      flatpak --system remove -y flathub net.opentabletdriver.OpenTabletDriver
    fi

# Install CNCF tools from curated Brewfile
[group('Apps')]
cncf:
    #!/usr/bin/env bash
    brew bundle --file=/usr/share/ublue-os/homebrew/cncf.Brewfile
    [[ -t 0 ]] && ujust --choose || true

# Install Goose and configure the read-only Linux diagnostics MCP server.
[group('Apps')]
install-ai-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    brew bundle --file=/usr/share/ublue-os/homebrew/ai-tools.Brewfile

    CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/goose"
    CONFIG_FILE="${CONFIG_DIR}/config.yaml"
    TEMPLATE="${GOOSE_TEMPLATE:-/usr/share/ublue-os/goose/config.yaml}"
    mkdir -p "${CONFIG_DIR}"

    if [[ -e "${CONFIG_FILE}" ]]; then
        echo "Goose config already exists: ${CONFIG_FILE}"
        echo "Review ${TEMPLATE} and merge its linux-mcp-server extension if needed."
        exit 0
    fi

    install -m0644 "${TEMPLATE}" "${CONFIG_FILE}"
    echo "Goose configured with read-only Linux diagnostics."

# Install ASUS laptop tools (asusctl daemon + ROG Control Center) | https://gitlab.com/asus-linux/asusctl
[group('Apps')]
install-asus:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing ASUS laptop tools..."
    brew tap ublue-os/tap 2>/dev/null || true
    brew trust ublue-os/tap 2>/dev/null || true
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
