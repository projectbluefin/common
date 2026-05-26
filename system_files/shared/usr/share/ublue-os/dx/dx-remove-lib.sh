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

dx_brew_bin() {
    if command -v brew &>/dev/null; then
        command -v brew
    elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        echo /home/linuxbrew/.linuxbrew/bin/brew
    else
        return 1
    fi
}

dx_remove_safe_brew_uninstall() {
    local tool=$1 brew_bin
    brew_bin=$(dx_brew_bin) || return 0
    if "$brew_bin" list --formula "$tool" &>/dev/null 2>&1 || \
       "$brew_bin" list "$tool" &>/dev/null 2>&1 || \
       "$brew_bin" list --cask "$tool" &>/dev/null 2>&1; then
        echo "  - Uninstalling $tool..."
        "$brew_bin" uninstall --ignore-dependencies "$tool" >/dev/null 2>&1 || true
    fi
}

# Mirrors dx_run_tools_body (uninstall dependents before podman; unlink podman when done).
dx_remove_tools_body() {
    local tool brew_bin
    # podman-tui/compose before podman; lima before podman-linked state matters less on remove
    for tool in podman-tui podman-compose kind lima ydotool ublue-os/experimental-tap/ydotool \
        android-platform-tools visual-studio-code-linux git-svn git-subrepo bpftop numactl \
        p7zip; do
        dx_remove_safe_brew_uninstall "$tool"
    done
    if brew_bin=$(dx_brew_bin); then
        dx_msg_muted "  → Unlinking podman after DX-Tools removal..."
        "$brew_bin" unlink podman >/dev/null 2>&1 || true
    fi
    if command -v npm &>/dev/null; then
        echo "  - Removing @devcontainers/cli (npm global)..."
        npm uninstall -g @devcontainers/cli >/dev/null 2>&1 || true
    fi
    echo "  - Removing DX-Tools flatpaks (user)..."
    flatpak uninstall --user -y --noninteractive org.flatpak.Builder \
        io.podman_desktop.PodmanDesktop >/dev/null 2>&1 || true
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

    dx_sudo_run "
        systemctl stop dockerd-dx.service 2>/dev/null || true
        systemctl disable dockerd-dx.service 2>/dev/null || true
        systemctl reset-failed dockerd-dx.service 2>/dev/null || true
        rm -f /etc/systemd/system/dockerd-dx.service
        rm -rf /usr/local/libexec/dx-next/docker
        systemctl daemon-reload
    "
}

dx_remove_virt_body() {
    flatpak uninstall --user -y --noninteractive org.virt_manager.virt-manager \
        org.virt_manager.virt_manager.Extension.Qemu >/dev/null 2>&1 || true

    dx_sudo_run "
        systemctl stop libvirt-dx.service 2>/dev/null || true
        systemctl disable libvirt-dx.service 2>/dev/null || true
        systemctl reset-failed libvirt-dx.service 2>/dev/null || true
        rm -f /etc/containers/systemd/libvirt-dx.container
        rm -f /etc/udev/rules.d/50-spice-usb.rules
        if [ -f /var/lib/dx-next/firewall-libvirt-zone-created ]; then
            firewall-cmd --permanent --delete-zone=libvirt >/dev/null 2>&1 || true
            rm -f /var/lib/dx-next/firewall-libvirt-zone-created
            rm -f /var/lib/dx-next/firewall-libvirt-target-set
            firewall-cmd --reload >/dev/null 2>&1 || true
        elif [ -f /var/lib/dx-next/firewall-libvirt-target-set ]; then
            firewall-cmd --permanent --zone=libvirt --set-target=default >/dev/null 2>&1 || true
            rm -f /var/lib/dx-next/firewall-libvirt-target-set
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

# Acquire sudo only before the first step that needs it (DX-Tools does not).
dx_remove_maybe_acquire_sudo() {
    if [ -n "${DX_SUDO_READY:-}" ]; then
        dx_extend_sudo_ticket
        return 0
    fi
    dx_acquire_sudo
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

    if [ "$remove_tools" = true ]; then
        dx_spin_run "󱗼 Uninstalling DX-Tools & Base Apps..." dx_remove_tools_body
    fi

    if [ "$remove_docker" = true ]; then
        dx_remove_maybe_acquire_sudo
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing Docker components..." dx_remove_docker_body
    fi

    if [ "$remove_virt" = true ]; then
        dx_remove_maybe_acquire_sudo
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing Libvirt/QEMU components..." dx_remove_virt_body
    fi

    if [ "$remove_incus" = true ]; then
        dx_remove_maybe_acquire_sudo
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing Incus components..." dx_remove_incus_body
    fi

    if [ "$remove_cockpit" = true ]; then
        dx_remove_maybe_acquire_sudo
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing Cockpit components..." dx_remove_cockpit_body
    fi

    if [ "$remove_groups" = true ]; then
        dx_remove_maybe_acquire_sudo
        dx_ensure_sudo_before_privileged_step
        dx_spin_run "󱗼 Removing DX groups configuration..." dx_remove_groups_body
    fi

    dx_msg_ok "Cleanup step complete."
}

dx_remove_all_full() {
    dx_remove_main --all
    if [ -f /var/lib/extensions/dx-next.raw ]; then
        dx_remove_maybe_acquire_sudo
        dx_sudo_run "
            rm -f /var/lib/extensions/dx-next.raw
            systemd-sysext refresh
        "
    fi
}

dx_remove_with_flags() {
    # shellcheck disable=SC2086
    dx_remove_main ${DX_REMOVE_FLAGS:-}
}
