#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

version-script damask-setup user 1 || exit 0

SETTINGS_DIR="${HOME}/.var/app/app.drey.Damask/config/glib-2.0/settings"
KEYFILE="${SETTINGS_DIR}/keyfile"

mkdir -p "${SETTINGS_DIR}"

if [[ ! -f "${KEYFILE}" ]]; then
	cat > "${KEYFILE}" << 'EOF'
[app/drey/Damask]
refresh-interval='86400'
enable-automatic-refresh=true
run-in-background=true
active-source='none'

[app/drey/Damask/sources/slideshow]
folder-uri='file:///run/host/usr/share/backgrounds/bluefin'
sort-by='random'
EOF
	chmod 0644 "${KEYFILE}"
fi

if systemctl --user list-unit-files damask.service &>/dev/null; then
	systemctl --user enable damask.service
fi
