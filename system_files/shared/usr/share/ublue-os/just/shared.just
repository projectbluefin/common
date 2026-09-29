# vim: set ft=make :
# These are recipes that are generic and should be available in bluefin and aurora

# Toggle LUKS auto-unlock via TPM2
[group('System')]
toggle-tpm2:
    @/usr/bin/luks-tpm2-autounlock

# Factory reset this device (experimental)
[group('System')]
powerwash:
    #!/usr/bin/bash
    FIRST_CONFIRMATION=$(gum choose --header='Warning: This is an experimental feature that will reset this device to its factory state.' "No" "Yes - wipe this machine")
    if [[ "$FIRST_CONFIRMATION" != "Yes - wipe this machine" ]]; then
        echo "Powerwash cancelled."
        exit 0
    fi
    SECOND_CONFIRMATION=$(gum choose --header='Are you sure?' "No" "Yes - wipe this machine")
    if [[ "$SECOND_CONFIRMATION" != "Yes - wipe this machine" ]]; then
        echo "Powerwash cancelled."
        exit 0
    fi
    sudo bootc install reset --experimental

# Toggle the rootless ffmpeg video thumbnailer (container quadlets + host daemon)
# Pass `enable`, `disable`, or `cancel` (case-insensitive) as ACTION, or run
# without arguments for the interactive prompt.
[group('System')]
toggle-ffmpeg-thumbnailer ACTION="prompt":
    #!/usr/bin/bash
    ACTION_VALUE="{{ ACTION }}"

    DAEMON_UNIT="ffmpeg-thumbnailer-daemon.service"
    # Array order is cosmetic: stop/mask/unmask take all three units in one
    # call, where argument order does not affect sequencing. The daemon still
    # gets SIGTERM before the containers go away because its unit orders itself
    # with After= on them, which is what lets it unlink its socket.
    THUMBNAILER_UNITS=(
        ffmpeg-thumbnailer-daemon.service
        ffmpeg-thumbnailer.service
        ffmpeg-thumbnailer-nvidia.service
    )
    # A same-named user drop-in overrides /usr/lib/environment.d, which
    # otherwise keeps the shim first in XDG_DATA_DIRS for video MIME types.
    ENV_OVERRIDE="${XDG_CONFIG_HOME:-${HOME}/.config}/environment.d/10-ffmpeg-thumbnailer.conf"

    if ! systemctl --user cat "${DAEMON_UNIT}" >/dev/null 2>&1 \
        && [[ -z "$(systemctl --user is-enabled "${DAEMON_UNIT}" 2>/dev/null)" ]]; then
        echo "The ffmpeg video thumbnailer is not installed on this system."
        exit 0
    fi

    _is_masked() {
        [[ "$(systemctl --user is-enabled "$1" 2>/dev/null)" == "masked" ]]
    }

    case "${ACTION_VALUE,,}" in
        enable)
            SELECTED_OPTION="Enable"
            ;;
        disable)
            SELECTED_OPTION="Disable"
            ;;
        cancel)
            exit 0
            ;;
        *)
            CURRENT_STATE="enabled"
            if _is_masked "${DAEMON_UNIT}"; then
                CURRENT_STATE="disabled"
            fi
            echo "The ffmpeg video thumbnailer is currently ${CURRENT_STATE}"
            SELECTED_OPTION="$(gum choose --header="Toggle the ffmpeg video thumbnailer?" "Enable" "Disable" "Cancel")"
            if [[ "${SELECTED_OPTION}" != "Enable" && "${SELECTED_OPTION}" != "Disable" ]]; then
                echo "No changes made."
                exit 0
            fi
            ;;
    esac

    if [[ "${SELECTED_OPTION}" == "Disable" ]]; then
        systemctl --user stop "${THUMBNAILER_UNITS[@]}" >/dev/null 2>&1 || true
        # Mask, not disable: the container units are quadlet-generated, so they
        # carry no install state `systemctl --user disable` can edit, and the
        # daemon ships `WantedBy=graphical-session.target default.target`, which
        # a preset or a re-enable can reinstate. Only a mask overrides both.
        # The per-user mask also blocks the container quadlets, so the 111 MB
        # image is never pulled again while the toggle is off.
        if systemctl --user mask "${THUMBNAILER_UNITS[@]}"; then
            mkdir -p "$(dirname "${ENV_OVERRIDE}")"
            printf '# Written by ujust toggle-ffmpeg-thumbnailer: masks the system drop-in.\n' > "${ENV_OVERRIDE}"
            echo "The ffmpeg video thumbnailer has been disabled"
            echo "Its container and daemon units are masked and stopped;"
            echo "after you log out and back in, video thumbnails fall back to the in-sandbox thumbnailer."
        else
            echo "Failed to disable the ffmpeg video thumbnailer" >&2
            exit 1
        fi
    else
        if systemctl --user unmask "${THUMBNAILER_UNITS[@]}"; then
            rm -f "${ENV_OVERRIDE}"
            systemctl --user daemon-reload >/dev/null 2>&1 || true
            systemctl --user enable --now --no-block "${DAEMON_UNIT}" >/dev/null 2>&1 || true
            # --no-block: the container quadlets carry TimeoutStartSec=900 and
            # pull a 111 MB image on their first start, so a blocking start
            # would stall this recipe for minutes with its output discarded.
            systemctl --user start --no-block "${THUMBNAILER_UNITS[@]}" >/dev/null 2>&1 || true
            echo "The ffmpeg video thumbnailer has been enabled"
            echo "Its units are unmasked and starting, but the shim only returns to"
            echo "XDG_DATA_DIRS at the next login, so video thumbnails come back"
            echo "after you log out and back in."
            echo "The container image is pulled in the background by that start, so"
            echo "the first thumbnails after logging back in may fail until it lands."
            echo "Run 'ujust status-ffmpeg-thumbnailer' to see whether it is up."
        else
            echo "Failed to enable the ffmpeg video thumbnailer" >&2
            exit 1
        fi
    fi

# Inspect the rootless ffmpeg video thumbnailer: units, container, socket, and
# recent daemon activity.
[group('System')]
status-ffmpeg-thumbnailer:
    #!/usr/bin/bash
    DAEMON_UNIT="ffmpeg-thumbnailer-daemon.service"
    THUMBNAILER_UNITS=(
        ffmpeg-thumbnailer.service
        ffmpeg-thumbnailer-nvidia.service
        ffmpeg-thumbnailer-daemon.service
    )
    CONTAINER_NAME="${FFT_CONTAINER:-ffmpeg-thumbnailer}"
    # Must match SOCK_PATH in /usr/libexec/ffmpeg-thumbnailer/ffmpeg-thumbnailer-daemon.
    SOCKET_PATH="${FFT_SOCKET:-${XDG_CACHE_HOME:-${HOME}/.cache}/gnome-desktop-thumbnailer/gstreamer-1.0/ffmpeg-thumbnailer/sock}"
    # Must match ENV_OVERRIDE in toggle-ffmpeg-thumbnailer.
    ENV_OVERRIDE="${XDG_CONFIG_HOME:-${HOME}/.config}/environment.d/10-ffmpeg-thumbnailer.conf"

    # Same probe as toggle-ffmpeg-thumbnailer, so both recipes agree on whether
    # the thumbnailer exists instead of printing unknown/absent rows for it.
    # The is-enabled fallback keeps a masked daemon counting as installed even
    # if `systemctl --user cat` fails on it.
    if ! systemctl --user cat "${DAEMON_UNIT}" >/dev/null 2>&1 \
        && [[ -z "$(systemctl --user is-enabled "${DAEMON_UNIT}" 2>/dev/null)" ]]; then
        echo "The ffmpeg video thumbnailer is not installed on this system."
        exit 0
    fi

    echo "Units (enabled-state / active-state):"
    for unit in "${THUMBNAILER_UNITS[@]}"; do
        ENABLED_STATE="$(systemctl --user is-enabled "${unit}" 2>/dev/null || true)"
        ACTIVE_STATE="$(systemctl --user is-active "${unit}" 2>/dev/null || true)"
        printf '  %-38s %-10s %s\n' "${unit}" "${ENABLED_STATE:-unknown}" "${ACTIVE_STATE:-unknown}"
    done

    echo "Container:"
    if command -v podman >/dev/null 2>&1; then
        if podman container exists "${CONTAINER_NAME}"; then
            podman ps --all --filter "name=^${CONTAINER_NAME}$"
        else
            echo "  ${CONTAINER_NAME}: not created (masked, stopped, or never started)"
        fi
    else
        echo "  podman is not installed"
    fi

    echo "Environment override:"
    if [[ -e "${ENV_OVERRIDE}" ]]; then
        echo "  ${ENV_OVERRIDE}: present"
        echo "  It shadows the system environment.d drop-in, so the shim stays out of"
        echo "  XDG_DATA_DIRS and video thumbnails stay off even if the units are unmasked."
        echo "  Run 'ujust toggle-ffmpeg-thumbnailer enable' to remove it."
    else
        echo "  ${ENV_OVERRIDE}: absent (system environment.d drop-in in effect)"
    fi

    echo "Daemon socket:"
    if [[ -S "${SOCKET_PATH}" ]]; then
        echo "  ${SOCKET_PATH}: listening"
    elif [[ -e "${SOCKET_PATH}" ]]; then
        echo "  ${SOCKET_PATH}: present but not a socket (stale)"
    else
        echo "  ${SOCKET_PATH}: missing (daemon not running)"
    fi

    echo "Recent daemon activity:"
    if command -v journalctl >/dev/null 2>&1; then
        journalctl --user -u "${DAEMON_UNIT}" -n 15 --no-pager 2>/dev/null || echo "  no journal entries recorded"
    else
        echo "  journalctl is not available"
    fi
