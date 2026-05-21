# shellcheck shell=bash
# DX-Next dev path bootstrap — sourced by scripts/dx-next-dev.sh only.
# Points DX_SHARE / DX_LIB at the git checkout so `ujust` recipes work on immutable /usr.
# Production images use /usr/share/ublue-os/... and never load this file.

dx_paths_init() {
    DX_PATHS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    DX_PATHS_SRC="${DX_PATHS_ROOT}/system_files/shared"

    export DX_UBLUE_ROOT="${DX_UBLUE_ROOT:-$DX_PATHS_SRC/usr/share/ublue-os}"
    export DX_SHARE="${DX_SHARE:-$DX_UBLUE_ROOT/dx}"
    export DX_LIB="${DX_LIB:-$DX_SHARE/dx-install-lib.sh}"
    export DX_REMOVE_LIB="${DX_REMOVE_LIB:-$DX_SHARE/dx-remove-lib.sh}"
    export DX_JUST_APPS="${DX_JUST_APPS:-$DX_UBLUE_ROOT/just/apps.just}"
    export PATH="${DX_PATHS_SRC}/usr/bin:${PATH}"

    export DX_SPIN_INLINE="${DX_SPIN_INLINE:-1}"
    export DX_SPIN_SHOW_OUTPUT="${DX_SPIN_SHOW_OUTPUT:-0}"
    export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
    export HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS:-1}"
    export HOMEBREW_NO_INSTALL_CLEANUP="${HOMEBREW_NO_INSTALL_CLEANUP:-1}"

    local missing=0
    for f in "$DX_LIB" "${DX_SHARE}/dx-ui-lib.sh" "$DX_SHARE/quadlets/libvirt-dx.container" "$DX_JUST_APPS"; do
        if [ ! -f "$f" ]; then
            echo "DX-Next: missing required file: $f" >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ]
}
