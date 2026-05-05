dx_justfile := "/usr/share/ublue-os/just/dx.just"

# Add user to all DX group with sysusers, this is always ran
dx-groups:
    #!/usr/bin/env bash
    sudo groupmod -g 5679 libvirt 2>/dev/null || true
    SYSUSERS_CONF="/etc/sysusers.d/dx-groups.conf"

    sudo mkdir -p /etc/sysusers.d/
    cat <<EOF | sudo tee $SYSUSERS_CONF > /dev/null
    g libvirt 5679
    g docker -
    g incus-admin -
    
    m $USER libvirt
    m $USER docker
    m $USER incus-admin
    EOF

# A developper's essential toolkit such as VSCode, podman-tui, etc
dx-tools:
    #!/usr/bin/env bash
    gum style --foreground 212 "󱁯 Installing DX-Tools & Base Apps..."
    brew bundle --file=/usr/share/ublue-os/homebrew/dx-next.Brewfile
    brew install --cask ublue-os/tap/visual-studio-code-linux


dx-docker:
    #!/usr/bin/env bash
    if [ -f /etc/os-release ]; then
    source /etc/os-release
    fi

    if [[ "$ID_LIKE" == *"org.gnome.os"* ]]; then
        just -f {{dx_justfile}} dx-docker-dakota
    else
        just -f {{dx_justfile}} dx-docker-se
    fi
    
# Docker for GnomeOS-like
dx-docker-dakota:
    #!/usr/bin/env bash
    gum style --foreground 212 "󰡨 Setting up Docker for Dakota..."
    sudo mkdir -p /etc/extensions/
    sudo mkdir -p /opt/extensions/
    sudo mkdir -p /etc/sysupdate.docker.d/
    curl -sSL "https://github.com/flatcar/sysext-bakery/releases/download/docker/docker.conf" \
    | sudo tee /etc/sysupdate.docker.d/docker.conf > /dev/null

    sudo /usr/lib/systemd/systemd-sysupdate -C docker update
    sudo systemd-sysext refresh

# Docker for SELinux
dx-docker-se:
    #!/usr/bin/env bash
    gum style --foreground 212 "󰡨 Setting up Docker for SELinux..."
    sudo install -d -m 0755 -o 0 -g 0 "/var/lib/extensions" "/var/lib/extensions.d"
    sudo restorecon -RFv "/var/lib/extensions" "/var/lib/extensions.d"
    sudo systemctl enable --now systemd-sysext.service
    sudo install -d -m 0755 -o 0 -g 0 "/etc/sysupdate.docker-ce.d"
    sudo restorecon -RFv "/etc/sysupdate.docker-ce.d"
    curl --silent --fail --location "https://extensions.fcos.fr/community/docker-ce.conf" \
    | sudo tee "/etc/sysupdate.docker-ce.d/docker-ce.conf"

    sudo /usr/lib/systemd/systemd-sysupdate update --component "docker-ce"
    sudo systemd-sysext refresh

# Setup qemu/libvirt using quadlets
dx-virt:
    #!/usr/bin/env bash
    gum style --foreground 212 "  Setting up Libvirt/QEMU..."
    flatpak install --system -y org.virt_manager.virt-manager
    flatpak install --system -y org.virt_manager.virt_manager.Extension.Qemu


    SOCKET_DIR="/run/libvirt-dx"
    echo 'SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664", GROUP="libvirt"' | sudo tee /etc/udev/rules.d/50-spice-usb.rules
    sudo mkdir -p /var/lib/libvirt-dx "$SOCKET_DIR"
    sudo chmod 775 "$SOCKET_DIR"

    if ! sudo firewall-cmd --permanent --get-zones | grep -qw libvirt; then
        sudo firewall-cmd --permanent --new-zone=libvirt
    fi
    sudo firewall-cmd --permanent --zone=libvirt --set-target=ACCEPT
    sudo firewall-cmd --reload

    sudo mkdir -p /etc/containers/systemd/
    sudo mkdir -p /var/lib/libvirt-dx/images/
    sudo cp /usr/share/ublue-os/dx/quadlets/libvirt-dx.container /etc/containers/systemd/
    sudo chgrp -R libvirt /var/lib/libvirt-dx/images
    sudo chmod -R 775 /var/lib/libvirt-dx/images

    sudo podman pull ghcr.io/jumpyvi/qemu-box:latest

    sudo systemctl daemon-reload
    sudo systemctl start libvirt-dx

    flatpak override --user --filesystem=/run/libvirt-dx org.virt_manager.virt-manager
    flatpak run org.virt_manager.virt-manager -c "qemu:///system?socket=/run/libvirt-dx/libvirt-sock" &>/dev/null &
    flatpak run org.virt_manager.virt-manager -c "qemu:///session" &>/dev/null &

# Setup incus and incus-webui with quadlet
dx-incus:
    #!/usr/bin/env bash
    gum style --foreground "#cc3d19" "  Enabling and Starting Incus..."
    brew install incus
    sudo cp /usr/share/ublue-os/dx/quadlets/incus-dx.container /etc/containers/systemd/
    sudo systemctl daemon-reload
    sudo systemctl start incus-dx

# Setup cockpit with quadlet
dx-cockpit:
    #!/usr/bin/env bash
    gum style --foreground "#2c77df" "  Enabling and Starting Cockpit..."
    sudo cp /usr/share/ublue-os/dx/quadlets/cockpit-dx.container /etc/containers/systemd/
    sudo systemctl daemon-reload
    sudo systemctl start cockpit-dx
