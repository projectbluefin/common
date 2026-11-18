#!/usr/bin/env bash
# Make the host `sushi` package (not the flatpak NautilusPreviewer) the
# Nautilus floating previewer, so office documents (docx/xlsx/pptx) preview
# through the org.libreoffice.LibreOffice Flatpak without per-user shims.
#
# Reversible and non-destructive: this hook installs nothing per-user and
# never touches a user-local override at
# ~/.local/share/dbus-1/services/. That override keeps precedence because
# $XDG_DATA_HOME is searched before /usr/local/share, so a user who customised
# their previewer keeps control and can still go back.
set -euo pipefail

# shellcheck disable=SC1091
source /usr/lib/ublue/setup-services/libsetup.sh

SERVICE_FILE="/usr/local/share/dbus-1/services/org.gnome.NautilusPreviewer.service"
TARGET="/usr/libexec/org.gnome.NautilusPreviewer"
USER_SERVICE="${HOME}/.local/share/dbus-1/services/org.gnome.NautilusPreviewer.service"

# If host sushi is not installed yet, do not record completion in version-script
# (it cannot be undone once written) so this retries next login.
if [[ ! -f "${SERVICE_FILE}" || ! -x "${TARGET}" ]]; then
    echo "preview-office: host sushi not installed, will retry on next login"
    exit 0
fi

if version-script "preview-office" user 1; then
    # Make the running session aware of the shipped service. The switch takes
    # effect on the next login regardless; this only helps the current one.
    systemctl --user daemon-reload || true
    echo "preview-office: host Sushi is the Nautilus floating previewer"

    if [[ -f "${USER_SERVICE}" ]]; then
        echo "preview-office: preserving existing user-local previewer override"
    fi
fi
