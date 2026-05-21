#!/usr/bin/env bash
# Dev helper for DX-Next (PR #288). Production entry point: ujust dx-next
#
# Usage:
#   dx-next-dev.sh              # same as: dx-next-dev.sh run
#   dx-next-dev.sh run          # interactive install/remove (apps.just dx-next)
#   dx-next-dev.sh deploy dev   # ~/.local snapshot (immutable /usr)
#   dx-next-dev.sh deploy system
#   dx-next-dev.sh link         # deploy dev + ~/.local/bin/ujust-dx-next
#   dx-next-dev.sh debug install Virt Docker
#   dx-next-dev.sh debug remove --all
#   dx-next-dev.sh debug docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/dx-paths.sh
source "$SCRIPT_DIR/lib/dx-paths.sh"

usage() {
    cat <<EOF
DX-Next dev helper (repo checkout). Shipped images use: ujust dx-next

Usage:
  $(basename "$0") [run]                 Interactive menu (default)
  $(basename "$0") deploy [dev|system]   Copy files for testing
  $(basename "$0") link                    deploy dev + install ujust-dx-next in ~/.local/bin
  $(basename "$0") debug <cmd> [args]    Non-interactive install/remove

Examples:
  $(basename "$0")
  DX_NONINTERACTIVE=1 DX_NEXT_CHOICES="Virt Docker" $(basename "$0") run
  $(basename "$0") debug install Virt Docker DX-Tools
  $(basename "$0") debug remove --all

See docs/dx-next.md
EOF
}

cmd_run() {
    dx_paths_init
    exec just --justfile "$DX_JUST_APPS" dx-next "$@"
}

cmd_deploy() {
    local mode="${1:-dev}"
    dx_paths_init
    local dev_root="${XDG_DATA_HOME:-$HOME/.local/share}/ublue-os-dev"

    case "$mode" in
        dev)
            mkdir -p "$dev_root/usr/bin" "$dev_root/usr/share/ublue-os/just"
            install -m755 "$DX_PATHS_SRC/usr/bin/dx-sudo-ensure" "$dev_root/usr/bin/dx-sudo-ensure"
            install -m755 "$DX_PATHS_SRC/usr/bin/dx-remove" "$dev_root/usr/bin/dx-remove"
            cp -a "$DX_PATHS_SRC/usr/share/ublue-os/dx" "$dev_root/usr/share/ublue-os/"
            cp -a "$DX_PATHS_SRC/usr/share/ublue-os/homebrew" "$dev_root/usr/share/ublue-os/"
            install -m644 "$DX_PATHS_SRC/usr/share/ublue-os/just/dx.just" "$dev_root/usr/share/ublue-os/just/dx.just"
            install -m644 "$DX_PATHS_SRC/usr/share/ublue-os/just/apps.just" "$dev_root/usr/share/ublue-os/just/apps.just"
            echo "Dev copy: $dev_root"
            echo "Prefer: $(basename "$0") run   (always uses this git checkout)"
            ;;
        system)
            if [ ! -w /usr/bin ] 2>/dev/null; then
                echo "Error: /usr is read-only (Silverblue/Bluefin). Use: $(basename "$0") deploy dev" >&2
                exit 1
            fi
            sudo install -Dm755 "$DX_PATHS_SRC/usr/bin/dx-sudo-ensure" /usr/bin/dx-sudo-ensure
            sudo install -Dm755 "$DX_PATHS_SRC/usr/bin/dx-remove" /usr/bin/dx-remove
            sudo cp -a "$DX_PATHS_SRC/usr/share/ublue-os/dx/." /usr/share/ublue-os/dx/
            sudo install -Dm644 "$DX_PATHS_SRC/usr/share/ublue-os/just/dx.just" /usr/share/ublue-os/just/dx.just
            sudo install -Dm644 "$DX_PATHS_SRC/usr/share/ublue-os/just/apps.just" /usr/share/ublue-os/just/apps.just
            echo "System install complete. Run: ujust dx-next"
            ;;
        *)
            echo "Unknown deploy mode: $mode (use dev or system)" >&2
            exit 1
            ;;
    esac
}

cmd_link() {
    cmd_deploy dev
    mkdir -p "$HOME/.local/bin"
    install -m755 "$SCRIPT_DIR/dx-next-dev.sh" "$HOME/.local/bin/dx-next-dev"
    ln -sf "$HOME/.local/bin/dx-next-dev" "$HOME/.local/bin/ujust-dx-next"
    echo "Installed: ~/.local/bin/ujust-dx-next -> dx-next-dev run"
}

cmd_debug() {
    dx_paths_init
    # shellcheck source=/dev/null
    source "$DX_LIB"
    # shellcheck source=/dev/null
    source "$DX_REMOVE_LIB"
    # shellcheck source=/dev/null
    source "${DX_SHARE}/dx-ui-lib.sh"

    local sub="${1:-install}"
    shift || true

    case "$sub" in
        install)
            dx_acquire_sudo
            dx_run_groups
            for choice in "$@"; do
                dx_apply_choice "$choice"
            done
            ;;
        remove)
            dx_acquire_sudo
            dx_remove_main "$@"
            ;;
        docker | virt | tools | incus | cockpit)
            dx_acquire_sudo
            case "$sub" in
                docker) dx_apply_choice "Docker" ;;
                virt) dx_apply_choice "Virt" ;;
                tools) dx_apply_choice "DX-Tools" ;;
                incus) dx_apply_choice "Incus" ;;
                cockpit) dx_apply_choice "Cockpit" ;;
            esac
            ;;
        -h | --help | help)
            echo "Usage: $(basename "$0") debug install|remove|docker|virt|tools|incus|cockpit [args...]" >&2
            exit 0
            ;;
        *)
            echo "Unknown debug command: $sub" >&2
            exit 1
            ;;
    esac
    echo "dx-next-dev debug: done."
}

main() {
    local cmd="${1:-run}"
    case "$cmd" in
        run | "") shift || true; cmd_run "$@" ;;
        deploy) shift; cmd_deploy "$@" ;;
        link) cmd_link ;;
        debug) shift; cmd_debug "$@" ;;
        -h | --help | help) usage ;;
        *)
            echo "Unknown command: $cmd" >&2
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
