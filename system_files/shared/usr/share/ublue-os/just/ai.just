# vim: set ft=make :
# RamaLama server port for local LLM

RAMALAMA_PORT := "8080"

# AI troubleshooting - one command does everything
[group('AI')]
troubleshoot:
    #!/usr/bin/bash
    set -euo pipefail

    echo "=== Bluespeed AI Troubleshooting ==="
    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # Auto-install missing dependencies (silent, no prompts)
    # ─────────────────────────────────────────────────────────────────────────

    if ! command -v goose &> /dev/null; then
        echo "Installing Goose CLI..."
        brew install block-goose-cli
    fi

    if ! command -v ramalama &> /dev/null; then
        echo "Installing RamaLama..."
        brew install ramalama
    fi

    if ! command -v linux-mcp-server &> /dev/null; then
        echo "Installing linux-mcp-server..."
        pip install --user linux-mcp-server
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Setup Goose config if missing
    # ─────────────────────────────────────────────────────────────────────────

    if [[ ! -f "${HOME}/.config/goose/bluespeed.yaml" ]]; then
        echo "Setting up Goose configuration..."
        mkdir -p "${HOME}/.config/goose"
        sed "s|__HOME__|${HOME}|g" /usr/share/ublue-os/goose/bluespeed.yaml > "${HOME}/.config/goose/bluespeed.yaml"
    fi

    echo ""

    # ─────────────────────────────────────────────────────────────────────────
    # Interactive provider selection via gum
    # ─────────────────────────────────────────────────────────────────────────

    CHOICE=$(gum choose --header="Select AI backend:" \
        "Local LLM (via RamaLama)" \
        "Cloud: Anthropic (Claude)" \
        "Cloud: OpenAI (GPT-4)" \
        "Cloud: Google (Gemini)" \
        "Cloud: OpenRouter" \
        "Cloud: Groq" \
        "Cloud: xAI (Grok)" \
        "Cloud: Azure OpenAI" \
        "Cloud: AWS Bedrock" \
        "Cancel")

    [[ "${CHOICE}" == "Cancel" || -z "${CHOICE}" ]] && echo "Cancelled." && exit 0

    # ─────────────────────────────────────────────────────────────────────────
    # Handle Local LLM (RamaLama) with smart model selection
    # ─────────────────────────────────────────────────────────────────────────

    if [[ "${CHOICE}" == "Local LLM (via RamaLama)" ]]; then

        # Build model selection menu
        MODEL_OPTIONS=()

        # First: Show already downloaded models (if any)
        echo "Checking downloaded models..."
        DOWNLOADED=$(ramalama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v "^$" || true)
        if [[ -n "${DOWNLOADED}" ]]; then
            MODEL_OPTIONS+=("─── Downloaded Models ───")
            while IFS= read -r model; do
                [[ -n "${model}" ]] && MODEL_OPTIONS+=("${model}")
            done <<< "${DOWNLOADED}"
            MODEL_OPTIONS+=("")
        fi

        # Second: Recommended models (with tool calling support and sufficient context)
        MODEL_OPTIONS+=("─── Recommended (Tool Calling + 128K Context) ───")
        MODEL_OPTIONS+=("ollama://phi4-mini (3.8B - Fast, tool calling)")
        MODEL_OPTIONS+=("ollama://llama3.2 (3B - Fast)")
        MODEL_OPTIONS+=("ollama://qwen2.5 (7B - Balanced)")
        MODEL_OPTIONS+=("ollama://granite3.1-dense (8B - IBM)")
        MODEL_OPTIONS+=("ollama://phi4 (14B - Best for tools)")
        MODEL_OPTIONS+=("ollama://mistral (7B - Classic)")

        # Third: Other available models
        MODEL_OPTIONS+=("")
        MODEL_OPTIONS+=("─── Other Models ───")
        MODEL_OPTIONS+=("ollama://gemma3:4b (4B - Google)")
        MODEL_OPTIONS+=("ollama://deepseek-r1 (7B - Reasoning)")
        MODEL_OPTIONS+=("ollama://codellama (7B - Code)")
        MODEL_OPTIONS+=("ollama://tinyllama (1B - Tiny, 2K context)")

        # Fourth: Custom model option
        MODEL_OPTIONS+=("")
        MODEL_OPTIONS+=("Enter custom model...")
        MODEL_OPTIONS+=("Cancel")

        # Let user choose model
        echo ""
        MODEL_CHOICE=$(gum choose --header="Select a model (tool calling required for MCP):" "${MODEL_OPTIONS[@]}")

        # Handle separators and empty choices
        [[ "${MODEL_CHOICE}" == "Cancel" || -z "${MODEL_CHOICE}" ]] && echo "Cancelled." && exit 0
        [[ "${MODEL_CHOICE}" == "───"* || "${MODEL_CHOICE}" == "" ]] && echo "Please select a model." && exit 1

        # Handle custom model entry
        if [[ "${MODEL_CHOICE}" == "Enter custom model..." ]]; then
            echo ""
            echo "Enter model in format: ollama://model-name or huggingface://org/repo/file.gguf"
            echo "Browse models at: https://ollama.com/library"
            SELECTED_MODEL=$(gum input --placeholder "ollama://model-name")
            [[ -z "${SELECTED_MODEL}" ]] && echo "No model provided." && exit 0
        else
            # Extract model name from choice (handles "ollama://phi4 (14B - Best)" format)
            SELECTED_MODEL=$(echo "${MODEL_CHOICE}" | awk '{print $1}')
        fi

        echo ""
        echo "Selected: ${SELECTED_MODEL}"

        # Check if model needs to be downloaded
        MODEL_SHORT=$(echo "${SELECTED_MODEL}" | sed 's|.*://||')
        if ! ramalama list 2>/dev/null | grep -q "${MODEL_SHORT}"; then
            echo ""
            echo "Downloading ${SELECTED_MODEL}..."
            echo "This may take several minutes depending on model size."
            ramalama pull "${SELECTED_MODEL}"
        fi

        # Check if server is already running (check health endpoint)
        if curl -s --max-time 2 http://127.0.0.1:{{ RAMALAMA_PORT }}/health &>/dev/null; then
            echo ""
            echo "Local LLM server already running on port {{ RAMALAMA_PORT }}"
            echo "Note: Using existing server. Run 'ujust stop-troubleshoot' first to use different model."
        else
            # Stop any existing bluespeed container
            ramalama stop bluespeed 2>/dev/null || true

            echo ""
            echo "Starting local LLM server with tool calling support..."

            # Start server in detached mode with named container
            # --jinja enables tool calling support required for MCP
            # --ctx-size 8192 provides sufficient context for MCP tool responses
            ramalama serve -d -p {{ RAMALAMA_PORT }} -n bluespeed \
                --runtime-args="--jinja" \
                --ctx-size 8192 \
                "${SELECTED_MODEL}"

            # Wait for server to be ready (up to 120 seconds for larger models)
            printf "Waiting for server"
            for i in {1..120}; do
                if curl -s --max-time 2 http://127.0.0.1:{{ RAMALAMA_PORT }}/health &>/dev/null; then
                    echo " ready!"
                    break
                fi
                # Check if container is still running
                if ! ramalama containers 2>/dev/null | grep -q "bluespeed"; then
                    echo ""
                    echo "Error: Server container exited. Checking logs..."
                    podman logs bluespeed 2>&1 | tail -20 || true
                    exit 1
                fi
                printf "."
                sleep 1
            done

            # Final check
            if ! curl -s --max-time 2 http://127.0.0.1:{{ RAMALAMA_PORT }}/health &>/dev/null; then
                echo ""
                echo "Error: Server failed to start within 120 seconds."
                echo "Container logs:"
                podman logs bluespeed 2>&1 | tail -20 || true
                exit 1
            fi
        fi

        # Set environment for Goose (RamaLama uses Ollama-compatible API)
        export OLLAMA_HOST="http://127.0.0.1:{{ RAMALAMA_PORT }}"
        # Override any existing Goose config to use local LLM
        export GOOSE_PROVIDER="ollama"
        # Extract model name from selection (e.g., "ollama://tinyllama" -> "tinyllama")
        MODEL_NAME="${SELECTED_MODEL#ollama://}"
        MODEL_NAME="${MODEL_NAME#huggingface://}"
        MODEL_NAME="${MODEL_NAME#oci://}"
        export GOOSE_MODEL="${MODEL_NAME}"
        echo ""
        echo "Using local LLM at ${OLLAMA_HOST} with model ${GOOSE_MODEL}"

    # ─────────────────────────────────────────────────────────────────────────
    # Handle Cloud Providers
    # ─────────────────────────────────────────────────────────────────────────

    elif [[ "${CHOICE}" == "Cloud: Anthropic (Claude)" ]]; then
        if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
            ANTHROPIC_API_KEY=$(gum input --placeholder "Enter Anthropic API key (sk-ant-...)" --password)
            [[ -z "${ANTHROPIC_API_KEY}" ]] && echo "No API key provided." && exit 0
            echo ""
            echo "Tip: export ANTHROPIC_API_KEY='...' in your shell config to persist"
        fi
        export GOOSE_PROVIDER="anthropic"
        export ANTHROPIC_API_KEY
        echo "Using Anthropic (Claude)"

    elif [[ "${CHOICE}" == "Cloud: OpenAI (GPT-4)" ]]; then
        if [[ -z "${OPENAI_API_KEY:-}" ]]; then
            OPENAI_API_KEY=$(gum input --placeholder "Enter OpenAI API key (sk-...)" --password)
            [[ -z "${OPENAI_API_KEY}" ]] && echo "No API key provided." && exit 0
            echo ""
            echo "Tip: export OPENAI_API_KEY='...' in your shell config to persist"
        fi
        export GOOSE_PROVIDER="openai"
        export OPENAI_API_KEY
        echo "Using OpenAI (GPT-4)"

    elif [[ "${CHOICE}" == "Cloud: Google (Gemini)" ]]; then
        if [[ -z "${GOOGLE_API_KEY:-}" ]]; then
            GOOGLE_API_KEY=$(gum input --placeholder "Enter Google API key" --password)
            [[ -z "${GOOGLE_API_KEY}" ]] && echo "No API key provided." && exit 0
            echo ""
            echo "Tip: export GOOGLE_API_KEY='...' in your shell config to persist"
        fi
        export GOOSE_PROVIDER="gemini"
        export GOOGLE_API_KEY
        echo "Using Google (Gemini)"

    elif [[ "${CHOICE}" == "Cloud: OpenRouter" ]]; then
        if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
            OPENROUTER_API_KEY=$(gum input --placeholder "Enter OpenRouter API key" --password)
            [[ -z "${OPENROUTER_API_KEY}" ]] && echo "No API key provided." && exit 0
            echo ""
            echo "Tip: export OPENROUTER_API_KEY='...' in your shell config to persist"
        fi
        export GOOSE_PROVIDER="openrouter"
        export OPENROUTER_API_KEY
        echo "Using OpenRouter"

    elif [[ "${CHOICE}" == "Cloud: Groq" ]]; then
        if [[ -z "${GROQ_API_KEY:-}" ]]; then
            GROQ_API_KEY=$(gum input --placeholder "Enter Groq API key" --password)
            [[ -z "${GROQ_API_KEY}" ]] && echo "No API key provided." && exit 0
            echo ""
            echo "Tip: export GROQ_API_KEY='...' in your shell config to persist"
        fi
        export GOOSE_PROVIDER="groq"
        export GROQ_API_KEY
        echo "Using Groq"

    elif [[ "${CHOICE}" == "Cloud: xAI (Grok)" ]]; then
        if [[ -z "${XAI_API_KEY:-}" ]]; then
            XAI_API_KEY=$(gum input --placeholder "Enter xAI API key" --password)
            [[ -z "${XAI_API_KEY}" ]] && echo "No API key provided." && exit 0
            echo ""
            echo "Tip: export XAI_API_KEY='...' in your shell config to persist"
        fi
        export GOOSE_PROVIDER="xai"
        export XAI_API_KEY
        echo "Using xAI (Grok)"

    elif [[ "${CHOICE}" == "Cloud: Azure OpenAI" ]]; then
        if [[ -z "${AZURE_OPENAI_API_KEY:-}" ]]; then
            echo "Azure OpenAI requires multiple settings:"
            echo ""
            AZURE_OPENAI_ENDPOINT=$(gum input --placeholder "Enter Azure endpoint (https://xxx.openai.azure.com)")
            [[ -z "${AZURE_OPENAI_ENDPOINT}" ]] && echo "No endpoint provided." && exit 0
            AZURE_OPENAI_DEPLOYMENT_NAME=$(gum input --placeholder "Enter deployment name")
            [[ -z "${AZURE_OPENAI_DEPLOYMENT_NAME}" ]] && echo "No deployment name provided." && exit 0
            AZURE_OPENAI_API_KEY=$(gum input --placeholder "Enter Azure API key" --password)
            [[ -z "${AZURE_OPENAI_API_KEY}" ]] && echo "No API key provided." && exit 0
            echo ""
            echo "Tip: Export these in your shell config to persist:"
            echo "  AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_DEPLOYMENT_NAME, AZURE_OPENAI_API_KEY"
        fi
        export GOOSE_PROVIDER="azure-openai"
        export AZURE_OPENAI_ENDPOINT
        export AZURE_OPENAI_DEPLOYMENT_NAME
        export AZURE_OPENAI_API_KEY
        echo "Using Azure OpenAI"

    elif [[ "${CHOICE}" == "Cloud: AWS Bedrock" ]]; then
        if [[ -z "${AWS_PROFILE:-}" ]] && [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
            echo "AWS Bedrock uses your AWS credentials."
            echo ""
            echo "Option 1: Set AWS_PROFILE"
            echo "Option 2: Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
            echo ""
            AWS_PROFILE=$(gum input --placeholder "Enter AWS profile name (or leave empty for access keys)")
            if [[ -z "${AWS_PROFILE}" ]]; then
                AWS_ACCESS_KEY_ID=$(gum input --placeholder "Enter AWS Access Key ID")
                [[ -z "${AWS_ACCESS_KEY_ID}" ]] && echo "No credentials provided." && exit 0
                AWS_SECRET_ACCESS_KEY=$(gum input --placeholder "Enter AWS Secret Access Key" --password)
                [[ -z "${AWS_SECRET_ACCESS_KEY}" ]] && echo "No credentials provided." && exit 0
                export AWS_ACCESS_KEY_ID
                export AWS_SECRET_ACCESS_KEY
            else
                export AWS_PROFILE
            fi
            AWS_REGION=$(gum input --placeholder "Enter AWS region (e.g., us-east-1)" --value "us-east-1")
            export AWS_REGION
        fi
        export GOOSE_PROVIDER="aws_bedrock"
        echo "Using AWS Bedrock"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Launch Goose session
    # ─────────────────────────────────────────────────────────────────────────

    echo ""
    echo "Starting troubleshooting session..."
    echo "Type 'exit' or press Ctrl+D to end."
    echo ""

    goose run --recipe "${HOME}/.config/goose/bluespeed.yaml" -s

# Stop local LLM server if running
[group('AI')]
stop-troubleshoot:
    #!/usr/bin/bash
    set -euo pipefail

    # Stop the bluespeed container using ramalama
    if ramalama containers 2>/dev/null | grep -q "bluespeed"; then
        echo "Stopping Bluespeed LLM server..."
        ramalama stop bluespeed
        echo "Server stopped."
    else
        echo "No Bluespeed server running."
    fi

    # Also stop any other ramalama containers (cleanup)
    OTHER_CONTAINERS=$(ramalama containers 2>/dev/null | grep -v "CONTAINER" | grep -v "bluespeed" | awk '{print $NF}' || true)
    if [[ -n "${OTHER_CONTAINERS}" ]]; then
        echo "Stopping other RamaLama containers..."
        for container in ${OTHER_CONTAINERS}; do
            ramalama stop "${container}" 2>/dev/null || true
        done
    fi

# List downloaded and available models
[group('AI')]
list-models:
    #!/usr/bin/bash
    if ! command -v ramalama &> /dev/null; then
        echo "RamaLama not installed. Run: ujust troubleshoot"
        exit 1
    fi

    echo "=== Downloaded Models ==="
    ramalama list
    echo ""
    echo "=== Available Shortnames ==="
    ramalama info 2>/dev/null | grep -A 100 '"Names"' | head -50 || echo "Run 'ramalama info' for full list"
    echo ""
    echo "Browse more models: https://ollama.com/library"
    echo "Pull a model: ramalama pull ollama://model-name"
