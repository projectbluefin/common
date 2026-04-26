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

# Setup rootless and rootfull docker with brew
dx-docker:
    #!/usr/bin/env bash
    just -f {{dx_justfile}} dx-docker-rootless
    just -f {{dx_justfile}} dx-docker-root


dx-docker-rootless:
    #!/usr/bin/env bash
    gum style --foreground 212 "󰡨 Setting up Rootless Docker..."
    
    brew install docker
    brew install --cask ublue-os/experimental-tap/dockerd-linux
    mkdir -p ~/.config/systemd/user/
    cp /usr/share/ublue-os/dx/units/user/dockerd-rootless-dx.service ~/.config/systemd/user/
    
    systemctl --user daemon-reload
    systemctl --user enable --now dockerd-rootless-dx

dx-docker-root:
    #!/usr/bin/env bash
    gum style --foreground 212 "󰡨 Setting up Rootfull Docker..."
    sudo cp /usr/share/ublue-os/dx/units/system/dockerd-dx.service /etc/systemd/system/
    brew install --cask ublue-os/experimental-tap/dockerd-linux
    brew install iptables docker
    sudo systemctl daemon-reload
    sudo systemctl enable --now dockerd-dx
    /home/linuxbrew/.linuxbrew/bin/docker context switch default


# Setup qemu/libvirt using quadlets
dx-virt:
    #!/usr/bin/env bash
    gum style --foreground 212 "  Setting up Libvirt/QEMU..."
    flatpak install -y org.virt_manager.virt-manager
    flatpak install -y org.virt_manager.virt_manager.Extension.Qemu


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
