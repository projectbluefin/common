# Per-component DX-Next recipes (install one stack piece at a time).
# Full menu flow: ujust dx-next (apps.just). Lib: dx/dx-install-lib.sh
# Dev: export DX_LIB and DX_SHARE to your git checkout (see dx/README.md)

dx_justfile := "/usr/share/ublue-os/just/dx.just"

# Internal helper — skipped when parent (dx-next) already acquired sudo on this TTY
_ensure-sudo:
    @dx-sudo-ensure

# Add user to all DX groups with sysusers; always run first during setup
dx-groups: _ensure-sudo
    #!/usr/bin/env bash
    set -euo pipefail
    # shellcheck source=/usr/share/ublue-os/dx/dx-install-lib.sh
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_groups

# Developer's toolkit (VSCode, podman-tui, etc.)
dx-tools: _ensure-sudo
    #!/usr/bin/env bash
    set -euo pipefail
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_tools

# Rootless and rootful docker via brew
dx-docker: _ensure-sudo
    #!/usr/bin/env bash
    set -euo pipefail
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_docker

dx-docker-rootless: _ensure-sudo
    #!/usr/bin/env bash
    set -euo pipefail
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_docker_rootless

dx-docker-root: _ensure-sudo
    #!/usr/bin/env bash
    set -euo pipefail
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_docker_root

# QEMU/libvirt via quadlets
dx-virt: _ensure-sudo
    #!/usr/bin/env bash
    set -euo pipefail
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_virt

dx-incus: _ensure-sudo
    #!/usr/bin/env bash
    set -euo pipefail
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_incus

dx-cockpit: _ensure-sudo
    #!/usr/bin/env bash
    set -euo pipefail
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_cockpit

# Run groups + selected components in one shell (one sudo TTY session)
dx-apply +choices:
    #!/usr/bin/env bash
    set -euo pipefail
    dx-sudo-ensure
    source "${DX_LIB:-/usr/share/ublue-os/dx/dx-install-lib.sh}"
    dx_run_groups
    for choice in "$@"; do
        dx_apply_choice "$choice"
    done

# Remove DX-Next tools and configurations
dx-remove-tools:
    @dx-remove --tools

dx-remove-docker:
    @dx-remove --docker

dx-remove-virt:
    @dx-remove --virt

dx-remove-incus:
    @dx-remove --incus

dx-remove-cockpit:
    @dx-remove --cockpit

dx-remove-all:
    @dx-remove --all

# Build the dx-next system extension image
build-dx-next:
    #!/usr/bin/env bash
    set -euo pipefail
    SOURCE_DIR=$(realpath "$(dirname "{{ justfile() }}")/../../../../")
    if [ ! -d "$SOURCE_DIR/usr" ]; then
        echo "Error: Could not find source directory (expected $SOURCE_DIR/usr to exist)."
        exit 1
    fi
    STAGING_DIR=$(mktemp -d)
    trap 'rm -rf "$STAGING_DIR"' EXIT

    echo "Staging files in $STAGING_DIR..."
    mkdir -p "$STAGING_DIR/usr"
    cp -r "$SOURCE_DIR/usr"/* "$STAGING_DIR/usr/"

    mkdir -p "$STAGING_DIR/usr/lib/extension-release.d"
    printf "ID=_any\nVERSION=1.0\n" > "$STAGING_DIR/usr/lib/extension-release.d/extension-release.dx-next"

    if command -v chcon &>/dev/null; then
        echo "Setting SELinux contexts..."
        chcon -R -t usr_t "$STAGING_DIR/usr" || true
    fi

    echo "Building dx-next.raw..."
    mksquashfs "$STAGING_DIR" dx-next.raw -all-root -noappend
    chmod 644 dx-next.raw
    echo "dx-next.raw built successfully."

# Install the dx-next system extension image
install-dx-next:
    #!/usr/bin/env bash
    set -euo pipefail
    dx-sudo-ensure
    if [ ! -f dx-next.raw ]; then
        echo "dx-next.raw not found. Running build-dx-next..."
        just -f "{{ justfile() }}" build-dx-next
    fi
    sudo mv dx-next.raw /var/lib/extensions/dx-next.raw
    sudo systemd-sysext refresh
    echo "dx-next extension installed and refreshed."
