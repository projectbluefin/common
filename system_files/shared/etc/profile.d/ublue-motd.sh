#!/usr/bin/env bash

# Guard against double-sourcing: /etc/profile and /etc/bashrc both source
# profile.d on GNOME OS / freedesktop-sdk based images (unlike Fedora which
# guards /etc/bashrc with shopt -q login_shell). Same pattern as BLING_SOURCED.
[ "${UBLUE_MOTD_SHOWN:-0}" -eq 1 ] && return 0
UBLUE_MOTD_SHOWN=1

[ ! -e "$HOME"/.config/no-show-user-motd ] && ublue-motd
