# shellcheck shell=bash
# DX-Next install library — sourced, never executed directly.
#
# Entry points:
#   - ujust dx-next        → apps.just (full menu, all components in one shell)
#   - ujust dx-docker etc. → dx.just (single component)
#   - dx-next-dev.sh debug install …
#
# Override paths when testing from a git checkout (see dx/README.md):
#   DX_SHARE, DX_UBLUE_ROOT, DX_LIB

DX_SHARE="${DX_SHARE:-/usr/share/ublue-os/dx}"
DX_UBLUE_ROOT="${DX_UBLUE_ROOT:-/usr/share/ublue-os}"
DX_SPIN_LIB="${DX_SHARE}/dx-install-lib.sh"

# shellcheck source=/usr/share/ublue-os/dx/dx-ui-lib.sh
source "${DX_SHARE}/dx-ui-lib.sh"

export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
export HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS:-1}"
export HOMEBREW_NO_INSTALL_CLEANUP="${HOMEBREW_NO_INSTALL_CLEANUP:-1}"

# --- Homebrew helpers (DX-Tools + Docker formulas) ---

dx_require_file() {
    if [ ! -f "$1" ]; then
        echo "DX-Next: missing required file: $1" >&2
        echo "Set DX_SHARE / DX_UBLUE_ROOT when testing from a git checkout." >&2
        return 1
    fi
}

dx_brew_unlink_if_installed() {
    local pkg
    for pkg in "$@"; do
        if brew list --formula "$pkg" &>/dev/null; then
            brew unlink "$pkg" 2>/dev/null || true
        fi
    done
}

# VS Code from the ublue cask (CLI prints version numbers only, not the product name).
dx_vscode_bin() {
    local candidate
    candidate="$(brew --prefix 2>/dev/null)/bin/code"
    if [ -x "$candidate" ] && brew list --cask visual-studio-code-linux &>/dev/null; then
        echo "$candidate"
        return 0
    fi
    return 1
}

dx_brew_link_if_installed() {
    local pkg
    for pkg in "$@"; do
        if brew list --formula "$pkg" &>/dev/null 2>&1; then
            brew link --overwrite "$pkg" 2>/dev/null || true
        elif brew list "$pkg" &>/dev/null 2>&1; then
            brew link --overwrite "$pkg" 2>/dev/null || true
        fi
    done
}

# Download static tarball to a file; optional SHA256 pin (set when bumping docker_ver).
dx_fetch_verified_tgz() {
    local url=$1 dest=$2 expected_sha=${3:-}
    if ! curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$dest"; then
        echo "DX-Next: failed to download $url" >&2
        return 1
    fi
    if [ ! -s "$dest" ]; then
        echo "DX-Next: empty download from $url" >&2
        return 1
    fi
    if [ -n "$expected_sha" ]; then
        local actual
        actual=$(sha256sum "$dest" | awk '{print $1}')
        if [ "$actual" != "$expected_sha" ]; then
            echo "DX-Next: SHA256 mismatch for $(basename "$dest")" >&2
            echo "  expected: $expected_sha" >&2
            echo "  actual:   $actual" >&2
            return 1
        fi
    fi
    if ! tar -tzf "$dest" >/dev/null 2>&1; then
        echo "DX-Next: archive failed integrity check: $(basename "$dest")" >&2
        return 1
    fi
}

dx_brew_install_if_missing() {
    local pkg
    for pkg in "$@"; do
        if brew list --formula "$pkg" &>/dev/null; then
            dx_msg_muted "  brew: ${pkg} already installed"
            brew link --overwrite "$pkg" 2>/dev/null || true
        else
            # Avoid brew's auto-link failure when bin/docker exists from a prior rootless static install
            if [ "$pkg" = docker ] && [ -e "$(brew --prefix 2>/dev/null)/bin/docker" ]; then
                dx_msg_muted "  brew: replacing existing docker binary before install"
                rm -f "$(brew --prefix)/bin/docker"
            fi
            brew install "$pkg" 2>/dev/null || brew install "$pkg" || true
            brew link --overwrite "$pkg" 2>/dev/null || true
        fi
    done
}

# --- DX groups (sysusers) — always run first on full install ---

dx_run_groups_body() {
    local sysusers_conf="/etc/sysusers.d/dx-groups.conf"
    # Never groupmod an existing host libvirt GID — only create the group when absent.
    dx_sudo_run "
        mkdir -p /etc/sysusers.d/
        {
            if ! getent group libvirt >/dev/null 2>&1; then
                echo 'g libvirt 5679'
            fi
            if ! getent group docker >/dev/null 2>&1; then
                echo 'g docker -'
            fi
            if ! getent group incus-admin >/dev/null 2>&1; then
                echo 'g incus-admin -'
            fi
            echo ''
            echo 'm ${USER} libvirt'
            echo 'm ${USER} docker'
            echo 'm ${USER} incus-admin'
        } > '${sysusers_conf}'
    "
}

dx_run_groups() {
    dx_spin_run "󰒕 Configuring DX groups..." dx_run_groups_body
}

dx_run_ydotool_install() {
    # Installed outside brew bundle (see dx-next.Brewfile).
    dx_msg_muted "  → ydotool (ublue-os/experimental-tap)..."
    if brew list --formula ydotool &>/dev/null 2>&1; then
        brew link --overwrite ydotool 2>/dev/null || true
        return 0
    fi
    if ! brew install ublue-os/experimental-tap/ydotool 2>/dev/null; then
        brew install ublue-os/experimental-tap/ydotool || true
    fi
    brew link --overwrite ydotool 2>/dev/null || true
}

# Brewfile formulas (lima/kind/podman-*/ydotool installed outside bundle).
dx_brewfile_formulas() {
    printf '%s\n' git-svn git-subrepo bpftop numactl p7zip podman-compose podman-tui lima kind
}

# Installed after core bundle so podman is not linked while lima dependencies pour/link.
dx_run_lima_kind_podman_install() {
    local pkg
    dx_msg_muted "  → lima, kind, podman-compose, podman-tui..."
    dx_brew_unlink_if_installed podman
    for pkg in lima kind podman-compose podman-tui; do
        if brew list --formula "$pkg" &>/dev/null 2>&1; then
            brew link --overwrite "$pkg" 2>/dev/null || true
        else
            brew install "$pkg" 2>/dev/null || brew install "$pkg" || true
            brew link --overwrite "$pkg" 2>/dev/null || true
        fi
    done
    dx_brew_link_if_installed podman
}

dx_brew_repair_dx_tools_links() {
    local pkg
    dx_msg_muted "  → Relinking brew formulas (overwrite)..."
    dx_brew_link_if_installed podman
    while IFS= read -r pkg; do
        [ -n "$pkg" ] && dx_brew_link_if_installed "$pkg"
    done < <(dx_brewfile_formulas)
}

dx_brew_bundle_dx_tools_ok() {
    local pkg
    while IFS= read -r pkg; do
        if ! brew list --formula "$pkg" &>/dev/null 2>&1; then
            return 1
        fi
    done < <(dx_brewfile_formulas)
    brew list --cask android-platform-tools &>/dev/null 2>&1
}

dx_run_tools_body() {
    export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
    local bundle_ret=0
    dx_sudo_touch_before_long_task
    dx_require_file "${DX_UBLUE_ROOT}/homebrew/dx-next.Brewfile"
    # Linked podman blocks other formulas from linking (systemd generator path); unlink for bundle.
    dx_msg_muted "  → Preparing brew (unlink podman during install)..."
    dx_brew_unlink_if_installed podman
    dx_msg_muted "  → brew bundle (core DX-Tools; may take several minutes)..."
    brew bundle --file="${DX_UBLUE_ROOT}/homebrew/dx-next.Brewfile" || bundle_ret=$?
    dx_run_lima_kind_podman_install
    dx_brew_repair_dx_tools_links
    dx_run_ydotool_install
    if [ "$bundle_ret" -ne 0 ]; then
        if dx_brew_bundle_dx_tools_ok; then
            dx_msg_warn "  brew bundle reported link errors; formulas were relinked and look complete."
            bundle_ret=0
        else
            dx_msg_warn "  brew bundle failed; check output above. Some DX-Tools packages may be missing."
        fi
    fi
    dx_msg_muted "  → VS Code (Homebrew cask)..."
    brew install --cask ublue-os/tap/visual-studio-code-linux || true
    if command -v npm &>/dev/null; then
        dx_msg_muted "  → @devcontainers/cli (npm global)..."
        npm install -g @devcontainers/cli --force || true
    else
        dx_msg_muted "  → Skipping npm devcontainers CLI (npm not found)"
    fi
    local vscode
    if vscode="$(dx_vscode_bin)"; then
        dx_msg_muted "  → VS Code extension: remote-containers..."
        if ! "$vscode" --install-extension ms-vscode-remote.remote-containers --force; then
            dx_msg_warn "Could not install remote-containers extension (run VS Code once if needed)."
        fi
    else
        dx_msg_warn "VS Code cask not found; skip remote-containers extension."
    fi
    dx_msg_muted "  → Flatpak: Builder, Podman Desktop..."
    flatpak install --user -y flathub org.flatpak.Builder || true
    flatpak install --user -y flathub io.podman_desktop.PodmanDesktop || true
    dx_sudo_touch_before_long_task
    return "$bundle_ret"
}

dx_run_tools() {
    dx_spin_run "󱁯 Installing DX-Tools & Base Apps..." dx_run_tools_body
}

# --- Docker: rootless (user systemd) then rootfull (dockerd-dx) ---

dx_run_docker_rootless_body() {
    export PATH="$(brew --prefix)/bin:${PATH}"
    dx_sudo_touch_before_long_task

    if systemctl --user is-active --quiet docker.service 2>/dev/null \
        && docker -H "unix:///run/user/$(id -u)/docker.sock" info &>/dev/null; then
        dx_msg_muted "Rootless Docker is already running; skipping setup."
        return 0
    fi

    dx_brew_install_if_missing docker slirp4netns fuse-overlayfs iproute2 iptables
    dx_brew_link_if_installed docker slirp4netns fuse-overlayfs iproute2 iptables
    dx_sudo_touch_before_long_task

    local docker_ver="29.5.2" setup_tool
    # Optional pins — update when bumping docker_ver (docker.com does not publish .sha256 files).
    local docker_tgz_sha="${DX_DOCKER_STATIC_SHA256:-}"
    local docker_rootless_sha="${DX_DOCKER_ROOTLESS_STATIC_SHA256:-}"
    local docker_base="https://download.docker.com/linux/static/stable/x86_64"
    setup_tool="$(brew --prefix)/bin/dockerd-rootless-setuptool.sh"
    local -a setup_args=(install --skip-iptables)

    if [ -S /var/run/docker.sock ] && docker info &>/dev/null 2>&1; then
        dx_msg_warn "Rootful Docker is active; continuing rootless setup with --force."
        setup_args+=(--force)
    fi

    local temp_dir docker_tgz rootless_tgz
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' RETURN
    docker_tgz="${temp_dir}/docker-${docker_ver}.tgz"
    rootless_tgz="${temp_dir}/docker-rootless-extras-${docker_ver}.tgz"
    dx_msg_muted "  → Downloading static Docker binaries v${docker_ver}..."
    dx_fetch_verified_tgz "${docker_base}/docker-${docker_ver}.tgz" "$docker_tgz" "$docker_tgz_sha"
    dx_fetch_verified_tgz "${docker_base}/docker-rootless-extras-${docker_ver}.tgz" "$rootless_tgz" "$docker_rootless_sha"
    dx_sudo_touch_before_long_task
    tar xzf "$docker_tgz" -C "$temp_dir" --strip-components=1
    tar xzf "$rootless_tgz" -C "$temp_dir" --strip-components=1

    local file filename dest
    for file in "$temp_dir"/*; do
        filename=$(basename "$file")
        dest="$(brew --prefix)/bin/$filename"
        if [ -L "$dest" ] || [ -f "$dest" ]; then
            rm -f "$dest"
        fi
        cp -af "$file" "$dest"
    done
    chmod +x "$(brew --prefix)/bin"/*
    rm -rf "$temp_dir"
    trap - RETURN

    dx_sudo_touch_before_long_task
    if ! "$setup_tool" "${setup_args[@]}"; then
        if systemctl --user is-active --quiet docker.service 2>/dev/null; then
            dx_msg_warn "Rootless setup tool reported an error, but user docker.service is active."
        else
            echo "Rootless Docker setup failed." >&2
            return 1
        fi
    fi
    dx_sudo_touch_before_long_task
}

dx_run_docker_rootless() {
    dx_spin_run "󰡨 Setting up Rootless Docker..." dx_run_docker_rootless_body
}

dx_run_docker_root_body() {
    local brew_prefix docker_bin unit_dest="/etc/systemd/system/dockerd-dx.service"
    brew_prefix="$(brew --prefix 2>/dev/null)"
    docker_bin="${brew_prefix}/bin/docker"

    if [ -f "$unit_dest" ] && systemctl is-enabled dockerd-dx &>/dev/null; then
        if systemctl is-active --quiet dockerd-dx 2>/dev/null && "$docker_bin" info &>/dev/null 2>&1; then
            dx_msg_muted "Rootfull dockerd-dx is already running."
        else
            dx_msg_muted "Rootfull dockerd-dx is installed; starting service..."
            dx_ensure_sudo_before_privileged_step
            dx_sudo_run "systemctl enable --now dockerd-dx"
        fi
        "$docker_bin" context use default 2>/dev/null || true
        return 0
    fi

    dx_msg_muted "  → Checking Homebrew docker / iptables..."
    dx_brew_install_if_missing iptables docker
    dx_brew_link_if_installed docker iptables
    dx_msg_muted "  → Installing systemd unit dockerd-dx..."
    dx_require_file "${DX_SHARE}/units/system/dockerd-dx.service"
    local unit_src="${DX_SHARE}/units/system/dockerd-dx.service"
    dx_ensure_sudo_before_privileged_step
    dx_sudo_run "
        cp '${unit_src}' /etc/systemd/system/dockerd-dx.service
        systemctl daemon-reload
        systemctl enable --now dockerd-dx
    "
    "$docker_bin" context use default 2>/dev/null || true
}

dx_run_docker_root() {
    dx_spin_run "󰡨 Setting up Rootfull Docker..." dx_run_docker_root_body
}

dx_run_docker() {
    dx_sudo_touch_before_long_task
    dx_run_docker_rootless
    dx_ensure_sudo_before_privileged_step
    dx_run_docker_root
}

# --- Virt: flatpaks + libvirt-dx quadlet ---

dx_run_virt_body() {
    if systemctl is-active --quiet libvirt-dx 2>/dev/null \
        && [ -f /etc/containers/systemd/libvirt-dx.container ]; then
        dx_msg_muted "Libvirt/QEMU (libvirt-dx) is already configured."
        return 0
    fi
    flatpak install --user -y flathub org.virt_manager.virt-manager
    flatpak install --user -y flathub org.virt_manager.virt_manager.Extension.Qemu
    dx_sudo_touch_before_long_task

    local quadlet="${DX_SHARE}/quadlets/libvirt-dx.container"
    dx_require_file "$quadlet"
    dx_ensure_sudo_before_privileged_step
    dx_sudo_run "
        echo 'SUBSYSTEM==\"usb\", ENV{DEVTYPE}==\"usb_device\", MODE=\"0664\", GROUP=\"libvirt\"' \
            > /etc/udev/rules.d/50-spice-usb.rules
        mkdir -p /var/lib/libvirt-dx /run/libvirt-dx
        chmod 775 /run/libvirt-dx
        if ! firewall-cmd --permanent --get-zones | grep -qw libvirt; then
            firewall-cmd --permanent --new-zone=libvirt
        fi
        firewall-cmd --permanent --zone=libvirt --set-target=ACCEPT
        firewall-cmd --reload || true
        mkdir -p /etc/containers/systemd/ /var/lib/libvirt-dx/images/
        cp '${quadlet}' /etc/containers/systemd/libvirt-dx.container
        chown -R root:libvirt /var/lib/libvirt-dx/images
        chmod -R 775 /var/lib/libvirt-dx/images
        systemctl daemon-reload
        systemctl start libvirt-dx
    "

    flatpak override --user --filesystem=/run/libvirt-dx org.virt_manager.virt-manager
    flatpak run --user org.virt_manager.virt-manager -c "qemu:///system?socket=/run/libvirt-dx/libvirt-sock" &>/dev/null &
    flatpak run --user org.virt_manager.virt-manager -c "qemu:///session" &>/dev/null &
}

dx_run_virt() {
    dx_spin_run "  Setting up Libvirt/QEMU..." dx_run_virt_body
}

# --- Incus: brew CLI + incus-dx quadlet (not in dx-next.Brewfile) ---

dx_run_incus_body() {
    if systemctl is-active --quiet incus-dx 2>/dev/null \
        && [ -f /etc/containers/systemd/incus-dx.container ]; then
        dx_msg_muted "Incus (incus-dx) is already configured."
        return 0
    fi
    dx_msg_muted "  → Homebrew incus (CLI client)..."
    dx_brew_install_if_missing incus
    dx_brew_link_if_installed incus
    local quadlet="${DX_SHARE}/quadlets/incus-dx.container"
    dx_require_file "$quadlet"
    dx_ensure_sudo_before_privileged_step
    dx_sudo_run "
        cp '${quadlet}' /etc/containers/systemd/incus-dx.container
        systemctl daemon-reload
        systemctl start incus-dx
    "
}

dx_run_incus() {
    dx_spin_run "  Enabling and Starting Incus..." dx_run_incus_body
}

# --- Cockpit: cockpit-dx quadlet ---

dx_run_cockpit_body() {
    if systemctl is-active --quiet cockpit-dx 2>/dev/null \
        && [ -f /etc/containers/systemd/cockpit-dx.container ]; then
        dx_msg_muted "Cockpit (cockpit-dx) is already configured."
        return 0
    fi
    local quadlet="${DX_SHARE}/quadlets/cockpit-dx.container"
    dx_require_file "$quadlet"
    dx_ensure_sudo_before_privileged_step
    dx_sudo_run "
        cp '${quadlet}' /etc/containers/systemd/cockpit-dx.container
        systemctl daemon-reload
        systemctl start cockpit-dx
    "
}

dx_run_cockpit() {
    dx_spin_run "  Enabling and Starting Cockpit..." dx_run_cockpit_body
}

# --- Post-install summary (called after each component in dx-next) ---

dx_report_component_status() {
    case "$1" in
        "DX-Tools")
            echo "" >&2
            dx_msg "── DX-Tools ──"
            if command -v code &>/dev/null || [ -x "$(brew --prefix 2>/dev/null)/bin/code" ]; then
                dx_msg_ok "  VS Code CLI available"
            else
                dx_msg_warn "  VS Code CLI not found"
            fi
            ;;
        "Docker")
            echo "" >&2
            dx_msg "── Docker ──"
            if systemctl --user is-active --quiet docker.service 2>/dev/null; then
                dx_msg_ok "  Rootless: user docker.service active"
            else
                dx_msg_warn "  Rootless: user docker.service not active"
            fi
            if systemctl is-active --quiet dockerd-dx 2>/dev/null; then
                dx_msg_ok "  Rootfull: dockerd-dx active"
            elif [ -f /etc/systemd/system/dockerd-dx.service ]; then
                dx_msg_warn "  Rootfull: dockerd-dx installed but not active (try: systemctl status dockerd-dx)"
            else
                dx_msg_warn "  Rootfull: dockerd-dx not installed"
            fi
            ;;
        "Virt")
            echo "" >&2
            dx_msg "── Virt ──"
            if systemctl is-active --quiet libvirt-dx 2>/dev/null; then
                dx_msg_ok "  libvirt-dx active"
            elif [ -f /etc/containers/systemd/libvirt-dx.container ]; then
                dx_msg_warn "  libvirt-dx configured but not active"
            else
                dx_msg_warn "  libvirt-dx not configured"
            fi
            ;;
        "Incus")
            echo "" >&2
            dx_msg "── Incus ──"
            if systemctl is-active --quiet incus-dx 2>/dev/null; then
                dx_msg_ok "  incus-dx active"
            else
                dx_msg_warn "  incus-dx not active"
            fi
            ;;
        "Cockpit")
            echo "" >&2
            dx_msg "── Cockpit ──"
            if systemctl is-active --quiet cockpit-dx 2>/dev/null; then
                dx_msg_ok "  cockpit-dx active"
            else
                dx_msg_warn "  cockpit-dx not active"
            fi
            ;;
    esac
}

# Map menu label → dx_run_* (apps.just loops CHOICES over this)
dx_apply_choice() {
    case "$1" in
        "DX-Tools") dx_run_tools ;;
        "Docker") dx_run_docker ;;
        "Virt") dx_run_virt ;;
        "Incus") dx_run_incus ;;
        "Cockpit") dx_run_cockpit ;;
        *) echo "Unknown component: $1" >&2; return 1 ;;
    esac
    dx_report_component_status "$1"
}
