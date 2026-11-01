# vim: set ft=make :

alias upgrade := update

# Update system, flatpaks and homebrew packages all at once
update:
    #!/usr/bin/bash
    if systemctl cat -- uupd.timer &> /dev/null; then
        SERVICE="uupd.service"
    else
        SERVICE="rpm-ostreed-automatic.service"
    fi
    if systemctl is-active --quiet "$SERVICE"; then
        echo "automatic updates are currently running, use \`journalctl -fexu $SERVICE\` to see logs"
        exit 1
    fi
    if rpm-ostree status --booted 2>/dev/null | grep -q "Layered packages:"; then
        echo "Status: Layered Packages Detected"
        echo "Run an \`rpm-ostree reset\` and try again. This removes the Zero Maintenance guarantee, take appropriate precautions!"
        exit 1
    fi
    echo "Starting OS image update (this may take a while as layers download)..."
    # bootc upgrade is documented as idempotent, but on composefs it exits 1 when
    # the newest image is already booted or staged ("same fs-verity digest"). Treat
    # that specific refusal as success; any other failure keeps its exit status.
    # Classify from this run's stderr (mirrored, stdout stays on the terminal);
    # never re-run bootc, since `bootc upgrade --check` can stage when the image
    # is already pulled.
    # Trade-off: stderr is a pipe here, so bootc's indicatif bars are hidden;
    # wrap in `script` if progress matters more than the extra dependency.
    upgrade_err="$(mktemp)"
    trap 'rm -f "${upgrade_err}"' EXIT
    exec 3>&1
    sudo bootc upgrade 2>&1 1>&3 | tee "${upgrade_err}" >&2
    upgrade_status=${PIPESTATUS[0]}
    if [[ "${upgrade_status}" -ne 0 ]]; then
        if grep -qF "Target image has the same fs-verity digest as the existing" "${upgrade_err}"; then
            echo "System image is already up to date."
        else
            exit "${upgrade_status}"
        fi
    fi
    # Updates system Flatpaks
    if flatpak remotes | grep -q system; then
        flatpak update -y
    fi
    # Update user Flatpaks
    if flatpak remotes | grep -q user; then
        flatpak update --user -y
    fi
    # Guard Brew if the user does not own brew/doesn't exist
    if [[ -O /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        # Upgrade will run brew update if needed
        /home/linuxbrew/.linuxbrew/bin/brew upgrade
    fi

alias auto-update := toggle-updates

# Turn automatic updates on or off
# Pass `enable`, `disable`, or `cancel` (case-insensitive) as ACTION or a
# positional argument (e.g. `ujust toggle-updates enable`) to run non-
# interactively without the gum prompt; the default

# ACTION="prompt" keeps the interactive prompt.
toggle-updates ACTION="prompt":
    #!/usr/bin/bash
    ACTION_VALUE="{{ ACTION }}"
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
            CURRENT_STATE="disabled"
            if systemctl is-enabled -q rpm-ostreed-automatic.timer; then
                CURRENT_STATE="enabled"
            elif systemctl is-enabled -q uupd.timer; then
                CURRENT_STATE="enabled"
            fi

            echo "Automatic updates are currently ${CURRENT_STATE}"
            SELECTED_OPTION="$(gum choose --header="Toggle automatic updates?" "Enable" "Disable" "Cancel")"
            [[ "${SELECTED_OPTION}" == "Cancel" || "${SELECTED_OPTION}" == "" ]] && exit 0
            ;;
    esac

    # uupd has a second trigger, uupd-resume.timer, that must follow the main
    # timer. The AC-connect trigger (uupd-on-ac.service) checks uupd.timer itself.
    # Only the main timer is started on enable: uupd-resume.timer is a
    # post-suspend one-shot (OnActiveSec=20min) and must only arm on resume.
    if systemctl cat -- uupd.timer &> /dev/null; then
        TIMERS=(uupd.timer uupd-resume.timer)
    else
        TIMERS=(rpm-ostreed-automatic.timer)
    fi
    if [ "${SELECTED_OPTION}" == "Enable" ] ; then
        sudo systemctl enable "${TIMERS[@]}"
        sudo systemctl start "${TIMERS[0]}"
        echo "Updates have been enabled"
    elif [ "${SELECTED_OPTION}" == "Disable" ] ; then
        sudo systemctl disable --now "${TIMERS[@]}"
        echo "Updates have been disabled"
    fi
