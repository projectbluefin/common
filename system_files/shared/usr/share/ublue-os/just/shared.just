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
    # Order matters: the daemon is stopped first so it unlinks its socket.
    THUMBNAILER_UNITS=(
        ffmpeg-thumbnailer-daemon.service
        ffmpeg-thumbnailer.service
        ffmpeg-thumbnailer-nvidia.service
    )

    if ! systemctl --user cat "${DAEMON_UNIT}" >/dev/null 2>&1; then
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
        # Mask, not disable: the daemon is also pulled in by a static
        # graphical-session.target.wants symlink shipped in /usr/lib, which
        # `disable` cannot remove. Only a mask overrides it.
        # The per-user mask also blocks the container quadlets, so the 111 MB
        # image is never pulled again while the toggle is off.
        if systemctl --user mask "${THUMBNAILER_UNITS[@]}"; then
            echo "The ffmpeg video thumbnailer has been disabled"
            echo "Its container and daemon units are masked and stopped;"
            echo "video thumbnails fall back to the in-sandbox thumbnailer."
        else
            echo "Failed to disable the ffmpeg video thumbnailer" >&2
            exit 1
        fi
    else
        if systemctl --user unmask "${THUMBNAILER_UNITS[@]}"; then
            systemctl --user daemon-reload >/dev/null 2>&1 || true
            systemctl --user enable --now "${DAEMON_UNIT}" >/dev/null 2>&1 || true
            systemctl --user start "${THUMBNAILER_UNITS[@]}" >/dev/null 2>&1 || true
            echo "The ffmpeg video thumbnailer has been enabled"
            echo "The container image is pulled on first use, so the first"
            echo "thumbnail after enabling may fail while the pull completes."
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
    SOCKET_PATH="${FFT_SOCKET:-${XDG_CACHE_HOME:-${HOME}/.cache}/gnome-desktop-thumbnailer/gstreamer-1.0/ffmpeg-thumbnailer.sock}"

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
