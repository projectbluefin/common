# shellcheck shell=bash
# DX-Next removal library — sourced from apps.just (same shell) or /usr/bin/dx-remove.
#
# Prefer sourcing over exec so sudo TTY ticket is not lost between menu and removal.
# Flags: --all | --tools | --docker | --virt | --incus | --cockpit
# See dx/README.md and docs/dx-next.md.

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1

DX_SHARE="${DX_SHARE:-/usr/share/ublue-os/dx}"
DX_SPIN_LIB="${DX_SHARE}/dx-remove-lib.sh"

# shellcheck source=/usr/share/ublue-os/dx/dx-ui-lib.sh
source "${DX_SHARE}/dx-ui-lib.sh"

# --- Homebrew uninstall (formula or cask) ---

dx_remove_safe_brew_uninstall() {
    local tool=$1
    if /home/linuxbrew/.linuxbrew/bin/brew list --formula "$tool" &>/dev/null || \
       /home/linuxbrew/.linuxbrew/bin/brew list --cask "$tool" &>/dev/null; then
        echo "  - Uninstalling $tool..."
        /home/linuxbrew/.linuxbrew/bin/brew uninstall --ignore-dependencies "$tool" >/dev/null 2>&1 || true
    fi
}

dx_remove_tools_body() {
    local tool
    for tool in kind lima devcontainer podman-tui ublue-os/experimental-tap/ydotool \
        android-platform-tools visual-studio-code-linux git-svn git-subrepo bpftop numactl \
        p7zip podman-compose squashfs; do
        dx_remove_safe_brew_uninstall "$tool"
    done
}

# --- Per-component teardown (order matters for --all: tools → docker → virt → incus → cockpit → groups) ---

dx_remove_docker_body() {
    systemctl --user stop docker.service 2>/dev/null || true
    systemctl --user disable docker.service 2>/dev/null || true

    if [ -f "/home/linuxbrew/.linuxbrew/bin/dockerd-rootless-setuptool.sh" ]; then
        /home/linuxbrew/.linuxbrew/bin/dockerd-rootless-setuptool.sh uninstall -f >/dev/null 2>&1 || true
    fi

    dx_remove_safe_brew_uninstall "docker"

    local bin
    for bin in dockerd docker-init docker-proxy dockerd-rootless.sh dockerd-rootless-setuptool.sh rootlesskit vpnkit; do
        rm -f "/home/linuxbrew/.linuxbrew/bin/$bin" || true
    done

    rm -rf ~/.local/share/docker || true
    rm -f ~/.config/systemd/user/dockerd-rootless-dx.service || true
    rm -f ~/.config/systemd/user/docker.service || true
    systemctl --user daemon-reload >/dev/null 2>&1 || true

    flatpak uninstall --user -y --noninteractive io.podman_desktop.PodmanDesktop >/dev/null 2>&1 || true

    dx_sudo_run "
        systemctl stop dockerd-dx.service 2>/dev/null || true
        systemctl disable dockerd-dx.service 2>/dev/null || true
        systemctl reset-failed dockerd-dx.service 2>/dev/null || true
        flatpak uninstall --system -y --noninteractive io.podman_desktop.PodmanDesktop >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/dockerd-dx.service
        systemctl daemon-reload
    "
}

dx_remove_virt_body() {
    flatpak uninstall --user -y --noninteractive org.virt_manager.virt-manager \
        org.virt_manager.virt_manager.Extension.Qemu org.flatpak.Builder >/dev/null 2>&1 || true

    dx_sudo_run "
        systemctl stop libvirt-dx.service 2>/dev/null || true
        systemctl disable libvirt-dx.service 2>/dev/null || true
        systemctl reset-failed libvirt-dx.service 2>/dev/null || true
        flatpak uninstall --system -y --noninteractive org.virt_manager.virt-manager \
            org.virt_manager.virt_manager.Extension.Qemu org.flatpak.Builder >/dev/null 2>&1 || true
        rm -f /etc/containers/systemd/libvirt-dx.container
        rm -f /etc/udev/rules.d/50-spice-usb.rules
        if firewall-cmd --permanent --get-zones | grep -qw libvirt; then
            firewall-cmd --permanent --delete-zone=libvirt >/dev/null 2>&1 || true
            firewall-cmd --reload >/dev/null 2>&1 || true
        fi
        systemctl daemon-reload
    "

    podman rm -f libvirt-dx 2>/dev/null || true
}

dx_remove_incus_body() {
    dx_remove_safe_brew_uninstall incus
    dx_sudo_run "
        systemctl stop incus-dx.service 2>/dev/null || true
        systemctl disable incus-dx.service 2>/dev/null || true
        systemctl reset-failed incus-dx.service 2>/dev/null || true
        rm -f /etc/containers/systemd/incus-dx.container
        systemctl daemon-reload
    "
    podman rm -f incus 2>/dev/null || true
}

dx_remove_cockpit_body() {
    dx_sudo_run "
        systemctl stop cockpit-dx.service 2>/dev/null || true
        systemctl disable cockpit-dx.service 2>/dev/null || true
        systemctl reset-failed cockpit-dx.service 2>/dev/null || true
        rm -f /etc/containers/systemd/cockpit-dx.container
        systemctl daemon-reload
    "
    podman rm -f cockpit-ws 2>/dev/null || true
}

dx_remove_groups_body() {
    dx_sudo_run "rm -f /etc/sysusers.d/dx-groups.conf"
}

# Usage: dx_remove_main [--all] [--tools] [--docker] [--virt] [--incus] [--cockpit]
dx_remove_main() {
    local remove_tools=false remove_docker=false remove_virt=false
    local remove_incus=false remove_cockpit=false remove_groups=false

    for arg in "$@"; do
        case "$arg" in
            --all)
                remove_tools=true remove_docker=true remove_virt=true
                remove_incus=true remove_cockpit=true remove_groups=true
                ;;
            --tools) remove_tools=true ;;
            --docker) remove_docker=true ;;
            --virt) remove_virt=true ;;
            --incus) remove_incus=true ;;
            --cockpit) remove_cockpit=true ;;
        esac
    done

    dx_acquire_sudo

    if [ "$remove_tools" = true ]; then
        dx_spin_run "󱗼 Uninstalling DX-Tools & Base Apps..." dx_remove_tools_body
        dx_extend_sudo_ticket
    fi

    if [ "$remove_docker" = true ]; then
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing Docker components..." dx_remove_docker_body
    fi

    if [ "$remove_virt" = true ]; then
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing Libvirt/QEMU components..." dx_remove_virt_body
    fi

    if [ "$remove_incus" = true ]; then
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing Incus components..." dx_remove_incus_body
    fi

    if [ "$remove_cockpit" = true ]; then
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing Cockpit components..." dx_remove_cockpit_body
    fi

    if [ "$remove_groups" = true ]; then
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing DX groups configuration..." dx_remove_groups_body
    fi

    dx_msg_ok "Cleanup step complete."
}

dx_remove_all_full() {
    dx_remove_main --all
    if [ -f /var/lib/extensions/dx-next.raw ]; then
        dx_sudo_run "
            systemd-sysext unmerge >/dev/null 2>&1 || true
            rm -f /var/lib/extensions/dx-next.raw
        "
    fi
}

dx_remove_with_flags() {
    # shellcheck disable=SC2086
    dx_remove_main ${DX_REMOVE_FLAGS:-}
}
