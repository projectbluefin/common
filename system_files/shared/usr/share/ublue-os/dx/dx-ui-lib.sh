# shellcheck shell=bash
# DX-Next terminal UI — messages, sudo session, and step runners.
#
# Sudo: Fedora ties tickets to the TTY. dx_acquire_sudo prompts once; a background
# keepalive runs `sudo -v` every 10s while the parent shell lives. Nested `just`
# or gum-spin children do not share that unless you stay in one shell (apps.just).
#
# DX_SUDO_READY     set after first successful dx_acquire_sudo
# DX_SPIN_INLINE=1  run step bodies in-process (default; avoids garbled brew output)
# DX_SPIN_INLINE=0  delegate to gum spin (subprocess; may re-prompt for sudo)

dx_msg() {
    gum style --foreground "${2:-212}" "$1" >&2 2>/dev/null || echo "$1" >&2
}

dx_msg_warn() {
    dx_msg "$1" 220
}

dx_msg_muted() {
    dx_msg "$1" 242
}

dx_msg_ok() {
    dx_msg "$1" 82
}

dx_msg_remove() {
    dx_msg "$1" 196
}

# One password per install/remove pass; keepalive extends the TTY ticket during long brew steps.
dx_acquire_sudo() {
    if ! sudo -n true 2>/dev/null; then
        dx_msg "Sudo access required for DX-Next. Please enter your password:"
        sudo -v
    fi
    export DX_SUDO_READY=1
    if [ -z "${DX_SUDO_KEEPALIVE_STARTED:-}" ]; then
        (while kill -0 "$$" 2>/dev/null; do
            if sudo -n true 2>/dev/null; then
                sudo -v 2>/dev/null || true
            fi
            sleep "${DX_SUDO_KEEPALIVE_SECS:-60}"
        done) 2>/dev/null &
        export DX_SUDO_KEEPALIVE_STARTED=1
    fi
}

# Extend ticket after long brew/download steps without prompting (when still valid).
dx_extend_sudo_ticket() {
    if [ -n "${DX_SUDO_READY:-}" ] && sudo -n true 2>/dev/null; then
        sudo -v 2>/dev/null || true
    fi
}

# Call before/after long steps that do not use sudo (brew, curl) to reduce re-prompts.
dx_sudo_touch_before_long_task() {
    dx_extend_sudo_ticket
}

dx_refresh_sudo() {
    if sudo -n true 2>/dev/null; then
        sudo -v 2>/dev/null || true
        return 0
    fi
    if [ -n "${DX_SUDO_READY:-}" ]; then
        dx_msg_muted "  Sudo session timed out — enter password once more:"
    else
        dx_msg "Sudo access required for DX-Next. Please enter your password:"
    fi
    sudo -v
}

dx_sudo_run() {
    dx_refresh_sudo
    sudo bash -euo pipefail -c "$1"
}

# Refresh or extend sudo ticket before a step that calls dx_sudo_run (install and remove).
dx_ensure_sudo_before_privileged_step() {
    if sudo -n true 2>/dev/null; then
        dx_extend_sudo_ticket
    else
        dx_refresh_sudo
    fi
}

# Run a step function. Default: same shell (clear logs, one sudo session).
# Set DX_SPIN_INLINE=0 to use gum spin subprocess (can garble output with brew).
dx_spin_run() {
    local title=$1
    local fn=$2
    shift 2 || true
    local ret=0

    echo "" >&2
    dx_msg "$title"

    if [ "${DX_SPIN_INLINE:-1}" = "1" ] || ! command -v gum &>/dev/null; then
        "$fn" "$@" || ret=$?
    else
        local share="${DX_SHARE:-/usr/share/ublue-os/dx}"
        local lib="${DX_SPIN_LIB:-${DX_LIB:-$share/dx-install-lib.sh}}"
        local lib_q ui_q
        lib_q=$(printf '%q' "$lib")
        ui_q=$(printf '%q' "$share/dx-ui-lib.sh")
        local spin_env=(
            "DX_SHARE=${DX_SHARE:-/usr/share/ublue-os/dx}"
            "DX_UBLUE_ROOT=${DX_UBLUE_ROOT:-/usr/share/ublue-os}"
            "DX_LIB=${DX_LIB:-}"
            "DX_REMOVE_LIB=${DX_REMOVE_LIB:-}"
            "DX_SUDO_READY=${DX_SUDO_READY:-}"
            "USER=${USER:-}"
            "HOME=${HOME:-}"
        )
        local sudo_keeper='if [ -n "${DX_SUDO_READY:-}" ]; then (while true; do sudo -v -n; sleep 15; kill -0 $$ || exit; done) 2>/dev/null & fi;'
        local -a spin_flags=(--spinner dot --spinner.foreground 212 --title "$title" --show-error)
        if [ "${DX_SPIN_SHOW_OUTPUT:-0}" = "1" ]; then
            spin_flags+=(--show-output)
        fi
        if [ "$#" -gt 0 ]; then
            env "${spin_env[@]}" gum spin "${spin_flags[@]}" -- \
                bash -c "source ${ui_q}; source ${lib_q}; ${sudo_keeper} ${fn} \"\$@\"" bash "$@" || ret=$?
        else
            env "${spin_env[@]}" gum spin "${spin_flags[@]}" -- \
                bash -c "source ${ui_q}; source ${lib_q}; ${sudo_keeper} ${fn}" || ret=$?
        fi
    fi

    if [ "$ret" -eq 0 ]; then
        dx_msg_ok "  Done."
    else
        dx_msg_warn "  Step failed (exit $ret)."
    fi
    return "$ret"
}

dx_show_complete_banner() {
    echo "" >&2
    dx_msg "────────────────────────────────────────────────────────────────"
    dx_msg "You are now testing the experimental DX mode. Please report any issues to the GitHub, or come talk with us on Discord!"
    dx_msg "Discord: https://discord.gg/8RZGC3uFzA"
    dx_msg "GitHub: https://github.com/projectbluefin/common"
    dx_msg "────────────────────────────────────────────────────────────────"
    dx_msg_warn "Please reboot to fully apply changes."
}
