# vim: set ft=make :

# NVIDIA AI Workspaces — deploy NGC containers as Podman Quadlet services
[group('AI')]
aimode:
    #!/usr/bin/bash
    set -euo pipefail

    STACKS_DIR="/usr/share/ublue-os/nvidia-stacks"
    QUADLET_DIR="${HOME}/.config/containers/systemd"

    # ── Preview mode: mock hardware for development on non-nvidia machines ────
    if [[ "${UJUST_PREVIEW:-}" == "1" ]]; then
        STACKS_DIR="${UJUST_PREVIEW_STACKS_DIR:-${STACKS_DIR}}"
        QUADLET_DIR="${UJUST_PREVIEW_QUADLET_DIR:-$(mktemp -d /tmp/quadlets-XXXXXX)}"
        nvidia-ctk() { case "${1:-}" in cdi) echo "nvidia.com/gpu=0  NVIDIA RTX 4090 (mocked)";; esac; }
        nvidia-smi() { printf 'NVIDIA GeForce RTX 4090, 24564\n'; }
        systemctl() {
            case "${*}" in
                *"is-active"*)                          return 1 ;;
                *"daemon-reload"*|*"start"*|*"stop"*)   echo "(preview: systemctl ${*})" ;;
                *) command systemctl "$@" ;;
            esac
        }
        podman() {
            case "${*}" in
                *"secret exists"*)           return 1 ;;
                *"secret create"*|*"login"*) echo "(preview: podman ${*})" ;;
                *) command podman "$@" ;;
            esac
        }
    fi

    if ! nvidia-ctk cdi list 2>/dev/null | grep -q 'nvidia.com/gpu'; then
        gum style --foreground 196 "✗  CDI not ready — is nvidia-cdi-refresh.service running?"
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
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 60 --padding "1 4" \
        "NVIDIA AI Workspaces" \
        "${GPU_LINE} · NGC ${NGC_MONTH}"
    echo ""

    # ── Build menu items ──────────────────────────────────────────────────────
    TMPFILE="$(mktemp)"
    trap 'rm -f "${TMPFILE}"' EXIT

    declare -a MENU_ITEMS=()
    declare -a MENU_KEYS=()
    LAST_CATEGORY=""

    while IFS=$'\t' read -r _order key _display; do
        # shellcheck source=/dev/null
        source "${STACKS_DIR}/${key}/stack.env"

        # Section separator when category changes
        if [[ "${STACK_CATEGORY}" != "${LAST_CATEGORY}" ]]; then
            case "${STACK_CATEGORY}" in
                nim)   MENU_ITEMS+=("── Local AI Models ──────────────────────────────────")  ;;
                dev)   MENU_ITEMS+=("── Development Labs ─────────────────────────────────")  ;;
                serve) MENU_ITEMS+=("── Inference Serving ────────────────────────────────")  ;;
                train) MENU_ITEMS+=("── Training ─────────────────────────────────────────")  ;;
                *)     MENU_ITEMS+=("── ${STACK_CATEGORY} ─────────────────────────────────") ;;
            esac
            MENU_KEYS+=("")
            LAST_CATEGORY="${STACK_CATEGORY}"
        fi

        STATUS="○"
        if systemctl --user is-active --quiet "${key}" 2>/dev/null; then
            STATUS="● active"
        elif compgen -G "${QUADLET_DIR}/${key}"*.container &>/dev/null 2>/dev/null; then
            STATUS="◎ deployed"
        fi

        AUTH=""
        [[ "${STACK_REQUIRES_NGC_AUTH:-false}" == "true" ]] && AUTH="  [NGC key]"

        MENU_ITEMS+=("  $(printf '%-16s' "${key}")  $(printf '%-36s' "${STACK_NAME} - ${STACK_DESC}")  ${STATUS}${AUTH}")
        MENU_KEYS+=("${key}")
    done < <(
        for stack_dir in "${STACKS_DIR}"/*/; do
            [[ -f "${stack_dir}/stack.env" ]] || continue
            (
                source "${stack_dir}/stack.env"
                KEY="$(basename "${stack_dir%/}")"
                printf '%03d\t%s\t.\n' "${STACK_ORDER:-50}" "${KEY}"
            )
        done | sort -t$'\t' -k1,1n
    )

    # ── Pick ──────────────────────────────────────────────────────────────────
    CHOSEN="$(gum choose \
        --height 16 \
        --cursor "▸  " \
        "${MENU_ITEMS[@]}")" || exit 0
    [[ -z "${CHOSEN}" ]] && exit 0

    # Separator selected — exit cleanly
    [[ "${CHOSEN}" == "──"* ]] && exit 0

    # Map chosen display line back to key via parallel array
    STACK_KEY=""
    for i in "${!MENU_ITEMS[@]}"; do
        if [[ "${MENU_ITEMS[$i]}" == "${CHOSEN}" ]]; then
            STACK_KEY="${MENU_KEYS[$i]}"
            break
        fi
    done
    [[ -z "${STACK_KEY}" ]] && exit 0

    STACK_DIR="${STACKS_DIR}/${STACK_KEY}"
    # shellcheck source=/dev/null
    source "${STACK_DIR}/stack.env"

    # ── Detail + action ───────────────────────────────────────────────────────
    echo ""
    IMAGE_TAG="$(grep '^Image=' "${STACK_DIR}/${STACK_KEY}.container" \
        | cut -d= -f2 \
        | envsubst '${NGC_MONTH}')"

    DETAIL=$(
        gum style --bold "${STACK_NAME}"
        echo "  ${STACK_DESC}"
        echo ""
        echo "  Image:  ${IMAGE_TAG}"
        echo "  VRAM:   ${STACK_VRAM_GB} GB minimum"
        echo "  Disk:   ~${STACK_DISK_GB} GB (first pull)"
        if [[ -n "${STACK_PORTS:-}" ]]; then
            echo ""
            for entry in ${STACK_PORTS}; do
                echo "  $(printf '%-8s' "${entry%%:*}"):  http://localhost:${entry##*:}"
            done
        fi
    )
    gum style \
        --border rounded --border-foreground 212 \
        --padding "1 3" --width 60 \
        "${DETAIL}"
    echo ""

    # ── NGC auth (NIM only) ───────────────────────────────────────────────────
    if [[ "${STACK_REQUIRES_NGC_AUTH:-false}" == "true" ]]; then
        if ! podman secret exists ngc-api-key 2>/dev/null; then
            gum style --foreground 212 "This stack requires an NGC API key."
            echo "  Free key: https://build.nvidia.com/"
            echo ""
            if gum confirm "Store NGC API key now?"; then
                NGC_KEY="$(gum input --password --placeholder="Paste NGC API key...")"
                [[ -z "${NGC_KEY}" ]] && exit 0
                printf '%s' "${NGC_KEY}" | podman secret create ngc-api-key -
                printf '%s' "${NGC_KEY}" | podman login nvcr.io \
                    --username '$oauthtoken' \
                    --password-stdin
                gum style --foreground 42 "✓ NGC key stored"
            fi
            echo ""
        fi
    fi

    # ── Already deployed: manage ──────────────────────────────────────────────
    if compgen -G "${QUADLET_DIR}/${STACK_KEY}"*.container &>/dev/null 2>/dev/null; then

        IS_ACTIVE=false
        systemctl --user is-active --quiet "${STACK_KEY}" 2>/dev/null && IS_ACTIVE=true

        if [[ "${IS_ACTIVE}" == "true" ]]; then
            ACTION="$(gum choose --height 8 --cursor "▸  " \
                "  Open in browser" \
                "  View logs" \
                "  Stop" \
                "  Redeploy (refresh quadlet files)" \
                "  Cancel")" || exit 0
        else
            ACTION="$(gum choose --height 8 --cursor "▸  " \
                "  Start" \
                "  Open in browser" \
                "  View logs" \
                "  Remove" \
                "  Cancel")" || exit 0
        fi

        case "${ACTION}" in
            "  Open in browser")
                FIRST_PORT="$(echo "${STACK_PORTS:-}" | grep -oP ':\K[0-9]+' | head -1)"
                [[ -n "${FIRST_PORT}" ]] && xdg-open "http://localhost:${FIRST_PORT}" &
                ;;
            "  View logs")
                journalctl --user -u "${STACK_KEY}" -f --no-pager
                ;;
            "  Start")
                gum spin --spinner dot --title "  Starting ${STACK_NAME}..." -- \
                    systemctl --user start "${STACK_KEY}"
                gum style --foreground 42 "✓ ${STACK_NAME} started"
                ;;
            "  Stop")
                systemctl --user stop "${STACK_KEY}"
                gum style --foreground 42 "✓ ${STACK_NAME} stopped"
                ;;
            "  Remove")
                systemctl --user stop "${STACK_KEY}" 2>/dev/null || true
                rm -f \
                    "${QUADLET_DIR}/${STACK_KEY}"*.container \
                    "${QUADLET_DIR}/${STACK_KEY}"*.network \
                    "${QUADLET_DIR}/${STACK_KEY}"*.volume \
                    2>/dev/null || true
                systemctl --user daemon-reload
                gum style --foreground 42 "✓ ${STACK_NAME} removed"
                ;;
            "  Redeploy (refresh quadlet files)")
                _aimode_write_quadlets
                gum style --foreground 42 "✓ Redeployed — restart to apply"
                ;;
        esac
        exit 0
    fi

    # ── Fresh deploy ──────────────────────────────────────────────────────────
    ACTION="$(gum choose --height 6 --cursor "▸  " \
        "  Deploy and start" \
        "  Deploy only" \
        "  Cancel")" || exit 0
    [[ "${ACTION}" == "  Cancel" || -z "${ACTION}" ]] && exit 0

    echo ""
    mkdir -p "${QUADLET_DIR}" "${HOME}/ai-workspaces/${STACK_KEY}"
    for f in "${STACK_DIR}"/*.container "${STACK_DIR}"/*.network "${STACK_DIR}"/*.volume; do
        [[ -f "${f}" ]] || continue
        dest="${QUADLET_DIR}/$(basename "${f}")"
        envsubst '${NGC_MONTH}' < "${f}" > "${dest}"
        gum style --foreground 42 "✓ $(basename "${dest}")"
    done
    systemctl --user daemon-reload
    echo ""

    if [[ "${ACTION}" == "  Deploy and start" ]]; then
        gum spin --spinner dot \
            --title "  Starting ${STACK_NAME} (first pull may take several minutes)..." -- \
            systemctl --user start "${STACK_KEY}"
        gum style --foreground 42 "✓ ${STACK_NAME} is running"
        echo ""
        if [[ -n "${STACK_PORTS:-}" ]]; then
            for entry in ${STACK_PORTS}; do
                echo "  http://localhost:${entry##*:}  (${entry%%:*})"
            done
            echo ""
        fi
    fi
