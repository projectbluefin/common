# vim: set ft=make :

# NVIDIA AI Workspaces — pick a stack, deploy it as a Podman Quadlet service
[group('AI')]
aimode:
    #!/usr/bin/bash
    set -euo pipefail

    STACKS_DIR="/usr/share/ublue-os/nvidia-stacks"
    QUADLET_DIR="${HOME}/.config/containers/systemd"

    # CDI must be live — always true on Bluefin NVIDIA after first boot
    if ! nvidia-ctk cdi list 2>/dev/null | grep -q 'nvidia.com/gpu'; then
        gum style --foreground 196 --bold \
            "✗  CDI not ready — is nvidia-cdi-refresh.service running?"
        gum style --foreground 245 \
            "   Try: systemctl status nvidia-cdi-refresh.service"
        exit 1
    fi

    NGC_MONTH="$(cat "${STACKS_DIR}/ngc-month" 2>/dev/null || echo "25.06")"
    export NGC_MONTH

    GPU_LINE="$(nvidia-smi --query-gpu=name,memory.total \
        --format=csv,noheader,nounits 2>/dev/null \
        | head -1 \
        | sed 's/,\s*/ · /; s/$/ MiB/' \
        || echo "GPU detected")"

    gum style \
        --border rounded \
        --border-foreground 76 \
        --padding "0 2" \
        "$(gum style --bold --foreground 76 '⚡ Bluefin AI Workspaces') · ${GPU_LINE} · NGC ${NGC_MONTH}"
    echo

    # ── Build sorted menu: ORDER\tKEY\tDISPLAY ────────────────────────────────
    TMPFILE="$(mktemp)"
    trap 'rm -f "${TMPFILE}"' EXIT

    for stack_dir in "${STACKS_DIR}"/*/; do
        [[ -f "${stack_dir}/stack.env" ]] || continue
        (
            # shellcheck source=/dev/null
            source "${stack_dir}/stack.env"
            KEY="$(basename "${stack_dir%/}")"

            STATUS="○"
            if systemctl --user is-active --quiet "${KEY}" 2>/dev/null; then
                STATUS="● active"
            elif compgen -G "${QUADLET_DIR}/${KEY}"*.container &>/dev/null 2>/dev/null; then
                STATUS="◎ deployed"
            fi

            AUTH=""
            [[ "${STACK_REQUIRES_NGC_AUTH:-false}" == "true" ]] && AUTH="  [NGC key]"

            printf '%03d\t%s\t  %-2s  %-28s  %-48s  %3dGB  %3dGB VRAM  %s%s\n' \
                "${STACK_ORDER:-50}" \
                "${KEY}" \
                "${STACK_ICON}" \
                "${STACK_NAME}" \
                "${STACK_DESC}" \
                "${STACK_DISK_GB:-0}" \
                "${STACK_VRAM_GB:-0}" \
                "${STATUS}" \
                "${AUTH}"
        )
    done | sort -t$'\t' -k1,1n >> "${TMPFILE}"

    [[ -s "${TMPFILE}" ]] || {
        gum style --foreground 196 "No stacks found in ${STACKS_DIR}"
        exit 1
    }

    # ── Pick ──────────────────────────────────────────────────────────────────
    CHOSEN="$(cut -f3- "${TMPFILE}" \
        | gum filter \
            --header="  Select a stack  ·  type to search  ·  ● active  ◎ deployed  ○ new" \
            --placeholder="Search stacks..." \
            --height=14 \
        2>/dev/null)" || exit 0
    [[ -z "${CHOSEN}" ]] && exit 0

    STACK_KEY="$(grep -F "${CHOSEN}" "${TMPFILE}" | head -1 | cut -f2)"
    [[ -z "${STACK_KEY}" ]] && {
        gum style --foreground 196 "Could not resolve selection."
        exit 1
    }

    STACK_DIR="${STACKS_DIR}/${STACK_KEY}"
    # shellcheck source=/dev/null
    source "${STACK_DIR}/stack.env"

    # ── Stack detail ──────────────────────────────────────────────────────────
    echo
    IMAGE_TAG="$(grep '^Image=' "${STACK_DIR}/${STACK_KEY}.container" \
        | cut -d= -f2 \
        | envsubst '${NGC_MONTH}')"
    gum style \
        --border normal --border-foreground 238 --padding "0 2" \
        "$(gum style --bold "${STACK_ICON}  ${STACK_NAME}")" \
        "$(gum style --foreground 245 "${STACK_DESC}")" \
        "" \
        "$(gum style --foreground 245 "Image:") ${IMAGE_TAG}" \
        "$(gum style --foreground 245 "VRAM:")  ${STACK_VRAM_GB} GB minimum" \
        "$(gum style --foreground 245 "Disk:")  ~${STACK_DISK_GB} GB (first pull)"
    echo

    # ── NGC auth (NIM stacks only) ────────────────────────────────────────────
    if [[ "${STACK_REQUIRES_NGC_AUTH:-false}" == "true" ]]; then
        if ! podman secret exists ngc-api-key 2>/dev/null; then
            gum style --foreground 214 --bold "  ⚠  This stack requires an NGC API key"
            gum style --foreground 245 \
                "  Free key: https://build.nvidia.com/" \
                "  (same key works for all NIM containers)"
            echo
            if gum confirm "  Store NGC API key now?"; then
                NGC_KEY="$(gum input --password --placeholder="Paste NGC API key...")"
                [[ -z "${NGC_KEY}" ]] && { echo "Cancelled."; exit 0; }
                printf '%s' "${NGC_KEY}" | podman secret create ngc-api-key -
                printf '%s' "${NGC_KEY}" | podman login nvcr.io \
                    --username '$oauthtoken' \
                    --password-stdin
                gum style --foreground 76 "  ✓  NGC key stored"
            else
                gum style --foreground 245 "  Continuing — container pull will fail without a key."
            fi
            echo
        else
            gum style --foreground 76 "  ✓  NGC key found"
            echo
        fi
    fi

    # ── Already deployed: show management menu ────────────────────────────────
    if compgen -G "${QUADLET_DIR}/${STACK_KEY}"*.container &>/dev/null 2>/dev/null; then

        IS_ACTIVE=false
        systemctl --user is-active --quiet "${STACK_KEY}" 2>/dev/null && IS_ACTIVE=true

        if [[ "${IS_ACTIVE}" == "true" ]]; then
            MGMT_ACTION="$(gum choose \
                --header="  ${STACK_ICON}  ${STACK_NAME} is running" \
                "Open in browser" \
                "View logs" \
                "Stop" \
                "Redeploy (refresh quadlet files)" \
                "Cancel")" || exit 0
        else
            MGMT_ACTION="$(gum choose \
                --header="  ${STACK_ICON}  ${STACK_NAME} is deployed but stopped" \
                "Start" \
                "Open in browser" \
                "View logs" \
                "Remove" \
                "Cancel")" || exit 0
        fi

        case "${MGMT_ACTION}" in
            "Open in browser")
                FIRST_PORT="$(echo "${STACK_PORTS:-}" | grep -oP ':\K[0-9]+' | head -1)"
                [[ -n "${FIRST_PORT}" ]] && xdg-open "http://localhost:${FIRST_PORT}" &
                ;;
            "View logs")
                journalctl --user -u "${STACK_KEY}" -f --no-pager
                ;;
            "Start")
                gum spin --spinner dot --title "  Starting ${STACK_NAME}..." -- \
                    systemctl --user start "${STACK_KEY}"
                gum style --foreground 76 "  ✓  ${STACK_NAME} started"
                if [[ -n "${STACK_PORTS:-}" ]]; then
                    echo
                    for entry in ${STACK_PORTS}; do
                        printf '  http://localhost:%s  (%s)\n' "${entry##*:}" "${entry%%:*}"
                    done
                fi
                ;;
            "Stop")
                systemctl --user stop "${STACK_KEY}"
                gum style --foreground 76 "  ✓  ${STACK_NAME} stopped"
                ;;
            "Remove")
                systemctl --user stop "${STACK_KEY}" 2>/dev/null || true
                rm -f \
                    "${QUADLET_DIR}/${STACK_KEY}"*.container \
                    "${QUADLET_DIR}/${STACK_KEY}"*.network \
                    "${QUADLET_DIR}/${STACK_KEY}"*.volume \
                    2>/dev/null || true
                systemctl --user daemon-reload
                gum style --foreground 76 "  ✓  ${STACK_NAME} removed"
                ;;
            "Redeploy (refresh quadlet files)")
                mkdir -p "${QUADLET_DIR}"
                mkdir -p "${HOME}/ai-workspaces/${STACK_KEY}"
                for f in "${STACK_DIR}"/*.container "${STACK_DIR}"/*.network "${STACK_DIR}"/*.volume; do
                    [[ -f "${f}" ]] || continue
                    dest="${QUADLET_DIR}/$(basename "${f}")"
                    envsubst '${NGC_MONTH}' < "${f}" > "${dest}"
                    printf '  %s wrote %s\n' "$(gum style --foreground 76 '✓')" "$(basename "${dest}")"
                done
                systemctl --user daemon-reload
                gum style --foreground 76 "  ✓  Redeployed — restart to pick up changes"
                ;;
            "Cancel"|"")
                exit 0
                ;;
        esac
        exit 0
    fi

    # ── Fresh deploy ──────────────────────────────────────────────────────────
    gum style --bold "  Quadlet files → ${QUADLET_DIR}/"
    for f in "${STACK_DIR}"/*.container "${STACK_DIR}"/*.network "${STACK_DIR}"/*.volume; do
        [[ -f "${f}" ]] || continue
        printf '    %s %s\n' "$(gum style --foreground 76 '+')" "$(basename "${f}")"
    done

    if [[ -n "${STACK_PORTS:-}" ]]; then
        echo
        gum style --bold "  Endpoints after start:"
        for entry in ${STACK_PORTS}; do
            printf '    %s %-10s → http://localhost:%s\n' \
                "$(gum style --foreground 76 '→')" \
                "${entry%%:*}" \
                "${entry##*:}"
        done
    fi
    echo

    DEPLOY_ACTION="$(gum choose \
        --header="  Deploy ${STACK_ICON} ${STACK_NAME}?" \
        "Deploy and start" \
        "Deploy only" \
        "Cancel")" || exit 0
    [[ "${DEPLOY_ACTION}" == "Cancel" || -z "${DEPLOY_ACTION}" ]] && exit 0

    mkdir -p "${QUADLET_DIR}"
    mkdir -p "${HOME}/ai-workspaces/${STACK_KEY}"

    echo
    for f in "${STACK_DIR}"/*.container "${STACK_DIR}"/*.network "${STACK_DIR}"/*.volume; do
        [[ -f "${f}" ]] || continue
        dest="${QUADLET_DIR}/$(basename "${f}")"
        envsubst '${NGC_MONTH}' < "${f}" > "${dest}"
        printf '  %s wrote %s\n' "$(gum style --foreground 76 '✓')" "$(basename "${dest}")"
    done
    systemctl --user daemon-reload
    gum style --foreground 76 "  ✓  daemon-reload done"

    if [[ "${DEPLOY_ACTION}" == "Deploy and start" ]]; then
        echo
        gum spin --spinner dot \
            --title "  Starting ${STACK_NAME} (first pull may take several minutes)..." -- \
            systemctl --user start "${STACK_KEY}"
        gum style --foreground 76 "  ✓  ${STACK_NAME} is running"
        if [[ -n "${STACK_PORTS:-}" ]]; then
            echo
            for entry in ${STACK_PORTS}; do
                printf '  http://localhost:%s  (%s)\n' "${entry##*:}" "${entry%%:*}"
            done
        fi
    fi

    echo
    gum style --bold "  Manage:"
    printf '    %-10s systemctl --user start %s\n'   "Start:"  "${STACK_KEY}"
    printf '    %-10s systemctl --user stop %s\n'    "Stop:"   "${STACK_KEY}"
    printf '    %-10s journalctl --user -u %s -f\n'  "Logs:"   "${STACK_KEY}"
    echo
