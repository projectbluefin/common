#!/usr/bin/env bash

if [ -e ~/.config/no-show-user-motd ]; then
	mkdir -p ~/.config/uwelcome
	mv ~/.config/no-show-user-motd ~/.config/uwelcome/disabled 2>/dev/null
fi

# Only greet a terminal: GDM starts the desktop session through a login shell,
# and uwelcome run there (no tty) asks for the portal before
# graphical-session.target is up, so xdg-desktop-portal fails its dependency
# and every portal call then waits out D-Bus's 120 s activation timeout.
# Skip for root: root shells (sudo su -, sudo -i) have no desktop session,
# and the portal lookup uwelcome makes can stall the prompt when the portal
# cannot start. Guard against double greetings when a shell chains into
# another (bash login shell starting fish): the first one wins.
if [ -t 1 ] && [ "$(id -u)" != "0" ] && [ -z "${UWELCOME_SHOWN-}" ]; then
	UWELCOME_SHOWN=1
	export UWELCOME_SHOWN
	uwelcome
fi
