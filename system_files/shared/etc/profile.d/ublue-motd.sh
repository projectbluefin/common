#!/usr/bin/env bash

[ ! -e "$HOME"/.config/no-show-user-motd ] && [ "${UBLUE_MOTD_SHOWN:-0}" != "1" ] && { export UBLUE_MOTD_SHOWN=1; ublue-motd; }
