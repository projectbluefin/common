# vim: set ft=make :

# AMD AI Workspaces — pick a stack, deploy it as a Podman Quadlet service
# GPU autodetection backend for ujust aimode (AMD path)
[group('AI')]
aimode-amd:
    #!/usr/bin/bash
    set -euo pipefail

    STACKS_DIR="/usr/share/ublue-os/amd-stacks"
    QUADLET_DIR="${HOME}/.config/containers/systemd"

    # KFD guard — /dev/kfd is the AMD compute interface (amdgpu driver required)
    if ! test -e /dev/kfd; then
        gum style --foreground 196 "✗ /dev/kfd not found — AMD GPU or amdgpu driver not available"
        gum style --foreground 245 "  Check: lsmod | grep amdgpu"
        exit 1
    fi

    # Render group check — required for rootless GPU access on Fedora
    if ! id -Gn | grep -qw render; then
        gum style --foreground 214 "  render group not set"
        gum style --foreground 245 \
            "  Fix: sudo usermod -aG render,video ${USER}  (then log out and back in)"
        echo ""
    fi

    ROCM_VERSION="$(cat "${STACKS_DIR}/rocm-version" 2>/dev/null || echo "7.2.4")"
    export ROCM_VERSION

    # ── Strix Halo detection via KFD topology ────────────────────────────────
    # gfx_target_version: gfx1151 = 0x1151 = 4433, gfx1150 = 0x1150 = 4432
    IS_STRIX=false
    for node_props in /sys/class/kfd/kfd/topology/nodes/*/properties; do
        [[ -f "${node_props}" ]] || continue
        gfx_ver="$(grep '^gfx_target_version' "${node_props}" 2>/dev/null \
            | awk '{print $2}' || true)"
        if [[ "${gfx_ver}" == "4433" || "${gfx_ver}" == "4432" ]]; then
            IS_STRIX=true
            break
        fi
    done

    # GPU info from sysfs — no host tools required
    GPU_NAME="AMD GPU"
    VRAM_GIB=0
    for card_dir in /sys/class/drm/card*/; do
        vendor="$(cat "${card_dir}/device/vendor" 2>/dev/null || true)"
        if [[ "${vendor}" == "0x1002" ]]; then
            GPU_NAME="$(cat "${card_dir}/device/product_name" 2>/dev/null || echo "AMD GPU")"
            vram_bytes="$(cat "${card_dir}/device/mem_info_vram_total" 2>/dev/null || echo "0")"
            VRAM_GIB="$(( vram_bytes / 1073741824 ))"
            break
        fi
    done

    GPU_SUBTITLE="${GPU_NAME} · ${VRAM_GIB} GB VRAM · ROCm ${ROCM_VERSION}"
    [[ "${IS_STRIX}" == "true" ]] && GPU_SUBTITLE="${GPU_NAME} · ${VRAM_GIB} GB unified · ROCm ${ROCM_VERSION} · Strix Halo"

    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 60 --padding "1 4" \
        "AMD AI Workspaces" \
        "${GPU_SUBTITLE}"
    echo ""

    # ── Strix Halo kargs warning ──────────────────────────────────────────────
    if [[ "${IS_STRIX}" == "true" ]]; then
        MISSING_KARGS=()
        grep -q 'amd_iommu=off'            /proc/cmdline || MISSING_KARGS+=("amd_iommu=off")
        grep -q 'amdgpu.gttsize=126976'    /proc/cmdline || MISSING_KARGS+=("amdgpu.gttsize=126976")
        grep -q 'ttm.pages_limit=32505856' /proc/cmdline || MISSING_KARGS+=("ttm.pages_limit=32505856")

        if [[ "${#MISSING_KARGS[@]}" -gt 0 ]]; then
            gum style --foreground 214 "  Strix Halo kargs not set — unified memory may be limited"
            gum style --foreground 245 \
                "  Missing: ${MISSING_KARGS[*]}" \
                "  Run: ujust amd-strix-setup   (5-12% performance boost, 124 GB iGPU)"
            echo ""
        else
            gum style --foreground 42 "  kargs set — 124 GB unified memory ready"
            echo ""
        fi
    fi

    # ── Build sorted menu ────────────────────────────────────────────────────
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
            [[ "${STACK_REQUIRES_HF_AUTH:-false}" == "true" ]] && AUTH="  [HF token]"

            printf '%03d\t%s\t  %-6s  %-24s  %-48s  %3dGB  %3dGB VRAM  %s%s\n' \
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
        gum style --foreground 196 "✗ no stacks found in ${STACKS_DIR}"
        exit 1
    }

    # Build parallel arrays for gum choose
    declare -a MENU_ITEMS MENU_KEYS
    while IFS=$'\t' read -r _order key display; do
        MENU_ITEMS+=("${display}")
        MENU_KEYS+=("${key}")
    done < "${TMPFILE}"

    # ── Pick ──────────────────────────────────────────────────────────────────
    CHOSEN="$(gum choose \
        --height 14 \
        --cursor "▸  " \
        --header "  Select a stack  ·  ● active  ◎ deployed  ○ new" \
        "${MENU_ITEMS[@]}")" || exit 0
    [[ -z "${CHOSEN}" ]] && exit 0

    STACK_KEY="$(grep -F "${CHOSEN}" "${TMPFILE}" | head -1 | cut -f2)"
    [[ -z "${STACK_KEY}" ]] && {
        gum style --foreground 196 "✗ could not resolve selection"
        exit 1
    }

    STACK_DIR="${STACKS_DIR}/${STACK_KEY}"
    # shellcheck source=/dev/null
    source "${STACK_DIR}/stack.env"
    export VLLM_MODEL="${VLLM_MODEL:-Qwen/Qwen2.5-7B-Instruct}"
    export LLAMA_MODEL="${LLAMA_MODEL:-/workspace/models/model.gguf}"

    # ── Stack detail ──────────────────────────────────────────────────────────
    echo ""
    IMAGE_TAG="$(grep '^Image=' "${STACK_DIR}/${STACK_KEY}.container" \
        | cut -d= -f2 \
        | envsubst '${ROCM_VERSION}')"

    DETAIL_BODY=$(
        gum style --bold "${STACK_NAME}"
        gum style --foreground 245 "${STACK_DESC}"
        echo ""
        gum style --foreground 245 "Image: ${IMAGE_TAG}"
        gum style --foreground 245 "VRAM:  ${STACK_VRAM_GB} GB minimum"
        gum style --foreground 245 "Disk:  ~${STACK_DISK_GB} GB (first pull)"
    )
    gum style \
        --border rounded --border-foreground 212 \
        --padding "1 3" --width 60 \
        "${DETAIL_BODY}"
    echo ""

    # ── Model path (llama.cpp stacks) ─────────────────────────────────────────
    if [[ "${STACK_KEY}" == "llama-strix" || "${STACK_KEY}" == "llama-vulkan" ]]; then
        MODELS_DIR="${HOME}/ai-workspaces/${STACK_KEY}/models"
        mkdir -p "${MODELS_DIR}"

        EXISTING_MODELS="$(find "${MODELS_DIR}" -name '*.gguf' 2>/dev/null | sort || true)"

        if [[ -z "${EXISTING_MODELS}" ]]; then
            gum style --foreground 214 "  no models found in ${MODELS_DIR}"
            gum style --foreground 245 \
                "  place a .gguf model there before starting, e.g.:" \
                "  hf download unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF \\" \
                "    --local-dir ${MODELS_DIR}/" \
                "" \
                "  will deploy with default path — update and restart after adding a model"
            echo ""
        else
            gum style --foreground 245 "  models in ${MODELS_DIR}:"
            while IFS= read -r model; do
                size="$(du -sh "${model}" 2>/dev/null | cut -f1 || echo "?")"
                printf '    %s  %-8s  %s\n' "*" "${size}" "$(basename "${model}")"
            done <<< "${EXISTING_MODELS}"

            FIRST_MODEL="$(echo "${EXISTING_MODELS}" | head -1)"
            export LLAMA_MODEL="/workspace/models/$(basename "${FIRST_MODEL}")"
            gum style --foreground 42 "  model: $(basename "${FIRST_MODEL}")"
            echo ""
        fi
    fi

    # ── HuggingFace token (vLLM and gated-model stacks) ──────────────────────
    if [[ "${STACK_REQUIRES_HF_AUTH:-false}" == "true" ]]; then
        if ! podman secret exists hf-token 2>/dev/null; then
            gum style --foreground 214 "  HuggingFace token not set"
            gum style --foreground 245 \
                "  a token unlocks gated models (Llama 3, Mistral, etc.)" \
                "  free token: https://huggingface.co/settings/tokens" \
                "  not needed for the default Qwen2.5-7B-Instruct model"
            echo ""
            if gum confirm "Store HuggingFace token now?"; then
                HF_TOKEN_VALUE="$(gum input --password --placeholder="paste HuggingFace token...")"
                [[ -z "${HF_TOKEN_VALUE}" ]] && { echo "cancelled"; exit 0; }
                printf '%s' "${HF_TOKEN_VALUE}" | podman secret create hf-token -
                gum style --foreground 42 "✓ HuggingFace token stored"
            else
                gum style --foreground 245 "  continuing — gated model downloads will fail without a token"
            fi
            echo ""
        else
            gum style --foreground 42 "✓ HuggingFace token found"
            echo ""
        fi
    fi

    # ── Already deployed: show management menu ────────────────────────────────
    if compgen -G "${QUADLET_DIR}/${STACK_KEY}"*.container &>/dev/null 2>/dev/null; then

        IS_ACTIVE=false
        systemctl --user is-active --quiet "${STACK_KEY}" 2>/dev/null && IS_ACTIVE=true

        if [[ "${IS_ACTIVE}" == "true" ]]; then
            MGMT_ACTION="$(gum choose \
                --height 8 \
                --cursor "▸  " \
                --header "  ${STACK_NAME} is running" \
                "  Open in browser" \
                "  View logs" \
                "  Stop" \
                "  Redeploy (refresh quadlet files)" \
                "  Cancel")" || exit 0
        else
            MGMT_ACTION="$(gum choose \
                --height 8 \
                --cursor "▸  " \
                --header "  ${STACK_NAME} is deployed but stopped" \
                "  Start" \
                "  Open in browser" \
                "  View logs" \
                "  Remove" \
                "  Cancel")" || exit 0
        fi

        case "${MGMT_ACTION}" in
            "  Open in browser")
                FIRST_PORT="$(echo "${STACK_PORTS:-}" | grep -oP ':\K[0-9]+' | head -1)"
                [[ -n "${FIRST_PORT}" ]] && xdg-open "http://localhost:${FIRST_PORT}" &
                ;;
            "  View logs")
                journalctl --user -u "${STACK_KEY}" -f --no-pager
                ;;
            "  Start")
                gum spin --spinner dot --title "  starting ${STACK_NAME}..." -- \
                    systemctl --user start "${STACK_KEY}"
                gum style --foreground 42 "✓ ${STACK_NAME} started"
                if [[ -n "${STACK_PORTS:-}" ]]; then
                    echo ""
                    for entry in ${STACK_PORTS}; do
                        printf '  http://localhost:%s  (%s)\n' "${entry##*:}" "${entry%%:*}"
                    done
                fi
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
                mkdir -p "${QUADLET_DIR}"
                mkdir -p "${HOME}/ai-workspaces/${STACK_KEY}"
                if [[ "${STACK_KEY}" == "lemonade" ]]; then
                    mkdir -p "${HOME}/ai-workspaces/lemonade/config"
                fi
                for f in "${STACK_DIR}"/*.container "${STACK_DIR}"/*.network "${STACK_DIR}"/*.volume; do
                    [[ -f "${f}" ]] || continue
                    dest="${QUADLET_DIR}/$(basename "${f}")"
                    envsubst '${ROCM_VERSION} ${VLLM_MODEL} ${LLAMA_MODEL}' < "${f}" > "${dest}"
                    if [[ "${f}" == *.container ]] \
                        && [[ "${STACK_REQUIRES_HF_AUTH:-false}" == "true" ]] \
                        && podman secret exists hf-token 2>/dev/null; then
                        echo "Secret=hf-token,type=env,target=HF_TOKEN" >> "${dest}"
                    fi
                    printf '  ✓ wrote %s\n' "$(basename "${dest}")"
                done
                systemctl --user daemon-reload
                gum style --foreground 42 "✓ redeployed — restart to pick up changes"
                ;;
            "  Cancel"|"")
                exit 0
                ;;
        esac
        exit 0
    fi

    # ── Fresh deploy ──────────────────────────────────────────────────────────
    gum style --foreground 245 "  quadlet files → ${QUADLET_DIR}/"
    for f in "${STACK_DIR}"/*.container "${STACK_DIR}"/*.network "${STACK_DIR}"/*.volume; do
        [[ -f "${f}" ]] || continue
        printf '    + %s\n' "$(basename "${f}")"
    done

    if [[ -n "${STACK_PORTS:-}" ]]; then
        echo ""
        gum style --bold "  endpoints after start:"
        for entry in ${STACK_PORTS}; do
            printf '    -> %-10s  http://localhost:%s\n' \
                "${entry%%:*}" \
                "${entry##*:}"
        done
    fi
    echo ""

    DEPLOY_ACTION="$(gum choose \
        --height 6 \
        --cursor "▸  " \
        --header "  Deploy ${STACK_NAME}?" \
        "  Deploy and start" \
        "  Deploy only" \
        "  Cancel")" || exit 0
    [[ "${DEPLOY_ACTION}" == "  Cancel" || -z "${DEPLOY_ACTION}" ]] && exit 0

    mkdir -p "${QUADLET_DIR}"
    mkdir -p "${HOME}/ai-workspaces/${STACK_KEY}"

    # Lemonade requires a backend config.json — create on first deploy
    if [[ "${STACK_KEY}" == "lemonade" ]]; then
        mkdir -p \
            "${HOME}/ai-workspaces/lemonade/config" \
            "${HOME}/ai-workspaces/lemonade/cache" \
            "${HOME}/ai-workspaces/lemonade/llama"
        if [[ ! -f "${HOME}/ai-workspaces/lemonade/config/config.json" ]]; then
            printf '{"llamacpp": {"backend": "rocm"}}\n' \
                > "${HOME}/ai-workspaces/lemonade/config/config.json"
            gum style --foreground 42 "✓ created lemonade config (ROCm backend)"
        fi
    fi

    # llama stacks — scaffold models dir with a README on first deploy
    if [[ "${STACK_KEY}" == "llama-strix" || "${STACK_KEY}" == "llama-vulkan" ]]; then
        mkdir -p "${HOME}/ai-workspaces/${STACK_KEY}/models"
        if [[ ! -f "${HOME}/ai-workspaces/${STACK_KEY}/models/README.md" ]]; then
            cat > "${HOME}/ai-workspaces/${STACK_KEY}/models/README.md" << 'EOF'
# Models

Place .gguf model files here. Example:

  hf download unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF \
    BF16/Qwen3-Coder-30B-A3B-Instruct-BF16-00001-of-00002.gguf \
    --local-dir ~/ai-workspaces/llama-strix/models/

Then redeploy: ujust aimode-amd -> Llama Strix -> Redeploy
EOF
        fi
    fi

    echo ""
    for f in "${STACK_DIR}"/*.container "${STACK_DIR}"/*.network "${STACK_DIR}"/*.volume; do
        [[ -f "${f}" ]] || continue
        dest="${QUADLET_DIR}/$(basename "${f}")"
        envsubst '${ROCM_VERSION} ${VLLM_MODEL} ${LLAMA_MODEL}' < "${f}" > "${dest}"
        if [[ "${f}" == *.container ]] \
            && [[ "${STACK_REQUIRES_HF_AUTH:-false}" == "true" ]] \
            && podman secret exists hf-token 2>/dev/null; then
            echo "Secret=hf-token,type=env,target=HF_TOKEN" >> "${dest}"
        fi
        printf '  ✓ wrote %s\n' "$(basename "${dest}")"
    done
    systemctl --user daemon-reload
    gum style --foreground 42 "✓ daemon-reload done"

    if [[ "${DEPLOY_ACTION}" == "  Deploy and start" ]]; then
        echo ""
        gum spin --spinner dot \
            --title "  starting ${STACK_NAME} (first pull may take several minutes)..." -- \
            systemctl --user start "${STACK_KEY}"
        gum style --foreground 42 "✓ ${STACK_NAME} started"
        if [[ -n "${STACK_PORTS:-}" ]]; then
            echo ""
            for entry in ${STACK_PORTS}; do
                printf '  http://localhost:%s  (%s)\n' "${entry##*:}" "${entry%%:*}"
            done
        fi
    fi

    echo ""
    gum style --bold "  manage:"
    printf '    %-10s systemctl --user start %s\n'   "start:"  "${STACK_KEY}"
    printf '    %-10s systemctl --user stop %s\n'    "stop:"   "${STACK_KEY}"
    printf '    %-10s journalctl --user -u %s -f\n'  "logs:"   "${STACK_KEY}"
    echo ""

# Set Strix Halo kernel parameters for optimal ROCm unified memory performance
# amd_iommu=off is 5-12% faster than iommu=pt (benchmarked by @urbanswelt, issue #66)
[group('AI')]
amd-strix-setup:
    #!/usr/bin/bash
    set -euo pipefail

    # Confirm Strix Halo hardware via KFD topology
    IS_STRIX=false
    for node_props in /sys/class/kfd/kfd/topology/nodes/*/properties; do
        [[ -f "${node_props}" ]] || continue
        gfx_ver="$(grep '^gfx_target_version' "${node_props}" 2>/dev/null \
            | awk '{print $2}' || true)"
        if [[ "${gfx_ver}" == "4433" || "${gfx_ver}" == "4432" ]]; then
            IS_STRIX=true
            break
        fi
    done

    if [[ "${IS_STRIX}" != "true" ]]; then
        gum style --foreground 196 "✗ no Strix Halo (gfx1151/gfx1150) detected"
        gum style --foreground 245 \
            "  this setup is only for Ryzen AI Max (Strix Halo) processors"
        exit 1
    fi

    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 60 --padding "1 4" \
        "Strix Halo — Kernel Parameter Setup"
    echo ""

    gum style --foreground 245 \
        "  these kargs unlock full 124 GiB iGPU unified memory and improve" \
        "  ROCm performance by 5-12% compared to the default iommu=pt setting"
    echo ""

    # Audit current kargs
    CURRENT_CMDLINE="$(cat /proc/cmdline)"
    _karg_ok() { echo "${CURRENT_CMDLINE}" | grep -q "$1" && echo "✓" || echo "○"; }

    gum style --bold "  parameter status:"
    printf '    %s  amd_iommu=off              disable AMD IOMMU — 5-12%% faster\n' \
        "$(_karg_ok 'amd_iommu=off')"
    printf '    %s  amdgpu.gttsize=126976      cap GPU unified memory to 124 GiB\n' \
        "$(_karg_ok 'amdgpu.gttsize=126976')"
    printf '    %s  ttm.pages_limit=32505856   cap pinned memory to 124 GiB\n' \
        "$(_karg_ok 'ttm.pages_limit=32505856')"
    echo ""

    # Check if already fully configured
    if echo "${CURRENT_CMDLINE}" | grep -q 'amd_iommu=off' \
        && echo "${CURRENT_CMDLINE}" | grep -q 'amdgpu.gttsize=126976' \
        && echo "${CURRENT_CMDLINE}" | grep -q 'ttm.pages_limit=32505856'; then
        gum style --foreground 42 "✓ all Strix Halo kargs already set"
        exit 0
    fi

    gum style --foreground 245 \
        "  will run:" \
        "  sudo rpm-ostree kargs \\" \
        "    --append-if-missing=amd_iommu=off \\" \
        "    --append-if-missing=amdgpu.gttsize=126976 \\" \
        "    --append-if-missing=ttm.pages_limit=32505856"
    echo ""

    gum confirm "Apply Strix Halo kernel parameters? (requires reboot)" || exit 0

    sudo rpm-ostree kargs \
        --append-if-missing=amd_iommu=off \
        --append-if-missing=amdgpu.gttsize=126976 \
        --append-if-missing=ttm.pages_limit=32505856

    echo ""
    gum style --foreground 42 "✓ kargs staged"
    gum style --foreground 245 "  reboot to activate — then run ujust aimode-amd"
    echo ""

    gum confirm "Reboot now?" && systemctl reboot || true
