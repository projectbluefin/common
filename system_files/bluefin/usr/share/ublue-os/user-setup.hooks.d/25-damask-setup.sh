#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

flatpak info app.drey.Damask &>/dev/null || exit 0

BREW_BIN="${BREW_BIN:-/home/linuxbrew/.linuxbrew/bin/brew}"
[[ -x "${BREW_BIN}" ]] || exit 0

# Homebrew's published wallpapers are nested; Slideshow needs its flat images
# folder. Keep a stable user-facing pointer, not copies or a version in settings.
CASK_DIR="$("${BREW_BIN}" --caskroom bluefin-wallpapers-extra)"
ARTWORK_VERSION="$("${BREW_BIN}" info --json=v2 --cask bluefin-wallpapers-extra | jq -r '.casks[0].installed // empty')"
ARTWORK_DIR="${CASK_DIR}/${ARTWORK_VERSION}/images"
[[ -n "${ARTWORK_VERSION}" && -d "${ARTWORK_DIR}" ]] || exit 0

mkdir -p "${HOME}/.local/share/backgrounds"
ln -sfnT "${ARTWORK_DIR}" "${HOME}/.local/share/backgrounds/bluefin-extra"
# A backgrounds grant alone does not expose the symlink's Homebrew target.
flatpak override --user --filesystem="${CASK_DIR}:ro" app.drey.Damask

version-script-check damask-setup user 1 || exit 0

SETTINGS_DIR="${HOME}/.var/app/app.drey.Damask/config/glib-2.0/settings"
KEYFILE="${SETTINGS_DIR}/keyfile"

mkdir -p "${SETTINGS_DIR}"

if [[ ! -f "${KEYFILE}" ]]; then
	cat > "${KEYFILE}" << EOF
[app/drey/Damask]
refresh-interval='86400'
enable-automatic-refresh=true
run-in-background=true
active-source='none'

[app/drey/Damask/sources/slideshow]
folder-uri='file://${HOME}/.local/share/backgrounds/bluefin-extra'
sort-by='random'
EOF
	chmod 0644 "${KEYFILE}"
fi

if systemctl --user list-unit-files damask.service &>/dev/null; then
	systemctl --user enable damask.service
fi

# Record success only after the body ran, so a failed first-boot run retries on
# the next boot instead of being permanently skipped
# (projectbluefin/common#1137).
version-script-commit damask-setup user 1
