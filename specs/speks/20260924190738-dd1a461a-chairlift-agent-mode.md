---
created_date: "2026-09-24"
document_status: draft
closed_date: null
---

# Feature: 20260924190738-dd1a461a-chairlift-agent-mode

## Overview

Bluefin users can activate a coherent local Agent Mode with a hardware-aware model choice, safe desktop assistance and an optional contributor flow. The experience must remain user-scoped, expose clear readiness and failure states, and avoid rewriting an existing agent or AI client configuration. Source: [chairlift#252](https://github.com/projectbluefin/chairlift/issues/252).

## Requirements

- [ ] **Prepare the local runtime**
  Users can enable a rootless llmman service bound to loopback, verify its actual backend and manage its lifecycle from ChairLift.
- [ ] **Choose a fitting model**
  The setup flow recommends five current chat-capable GGUF model families using live artifact sizes and memory data, with a dated offline fallback.
- [ ] **Expose Agent Mode controls**
  A user sees installation state, model choice, launch actions and explicit errors rather than a success-looking inert panel.
- [ ] **Open Ask Bluefin safely**
  The menu and shortcut open configuration until ready; when ready they launch the approved Jan experience.
- [ ] **Offer isolated assistant clients**
  Goose and Oh My Pi can use the selected local model and constrained Linux/Bluefin MCP for their session without overwriting the user’s defaults.
- [ ] **Use only safe local access**
  The ordinary daemon remains loopback-only; peer offload consumes a manually prepared remote without turning this computer into a serving peer.
- [ ] **Offer a preflighted contribution path**
  People can launch the contributor appliance after a visible doctor check, without promising local-model donation until the appliance actually supports it.
- [ ] **Qualify real use**
  A fresh and configured installation passes desktop E2E, OMP benchmark/soak and documented screenshots.

## Constraints

- Use llmman, not the older RamaLama path in chairlift#195; no Lemonade, pkexec or default OpenAI SDK redirect.
- Disable prompt-history persistence by default; Linux MCP must run with --toolset FIXED and remote-host access opt-in.
- Use llmman config set/get for aliases, peers and auth instead of writing TOML independently; OLLAMA_HOST is the supported session discovery variable.
- Jan’s Flatpak is x86_64-only in the source plan; do not claim readiness elsewhere until platform and exact Tauri-origin behavior are verified.

## Acceptance Criteria

- [ ] **Prepare the local runtime**
  A fresh user enable/disable cycle observes a service at 127.0.0.1:17434 with LLMMAN_SHELL=off, history disabled and truthful backend status.
- [ ] **Choose a fitting model**
  For each tested hardware class, recommendations use llmman routing memory and actual GGUF metadata, rejecting oversized or non-chat/safetensors-only artifacts.
- [ ] **Expose Agent Mode controls**
  Control surface and launch intents work for fresh, already configured, offline, failed and unsupported states.
- [ ] **Open Ask Bluefin safely**
  Menu and Ctrl+Alt+Backspace dispatch the same readiness state; Jan launches only on supported architecture and verified origin/CORS contract.
- [ ] **Offer isolated assistant clients**
  Existing Goose config and global OMP auth, profiles, sessions, caches, models and MCP entries remain byte-identical after setup and launch.
- [ ] **Use only safe local access**
  A new install exposes no LAN listener, SSH-key discovery, remote host tools or firewall changes; a configured client-only peer works.
- [ ] **Offer a preflighted contribution path**
  The closed #653 selected endpoint seam is retained; preflight fails visibly if runtime isolation cannot access the selected llmman endpoint.
- [ ] **Qualify real use**
  Cross-repo packaging/menu and launcher dependencies are complete and the real GUI/client paths pass before readiness is claimed.

## Technical Approach

- Locked decisions: product name Agent Mode; llmman runtime; rootless user service; no RamaLama migration/cache cleanup; named OMP profile; Goose provider selected for that launch only.
- Risk checks in the issue: NVIDIA acceleration needs a working container runtime/toolkit; model names do not prove size or modality; GET /llmman/node is routing-memory authority; goose-mcp-setup must merge rather than overwrite config and must not solicit SSH keys.
- Native work map #253–#264 plus #686/#687, #1163/#1164 covers architecture, llmman, model catalog, control surface, Goose, OMP, peers, dispatcher, discovery, contribution and acceptance. #653 is closed; all other children shown open at inventory.
- Source locked decisions and risks preserved below.

### Locked decisions

- Product name: **Agent Mode**. Runtime: **llmman**. Lemonade is outside this epic.
- Replace the current RamaLama-backed Local AI implementation; do not build RamaLama migration or cache cleanup.
- No `pkexec` path for Agent Mode. Installation and service state remain user-scoped.
- The ordinary daemon stays loopback-only, sets `LLMMAN_SHELL=off` literally, and disables prompt-history persistence by default because diagnostic prompts can contain system details.
- Use `llmman config set/get`, not a second TOML writer, for aliases, peers, and authentication.
- `OLLAMA_HOST` is the safe session-wide discovery variable. Redirecting all OpenAI SDK users is explicit opt-in, not a default.
- ChairLift never rewrites Goose provider ownership. Goose is pointed at llmman for that launch.
- OMP integration uses a named profile; global OMP auth, sessions, settings, caches, models, and MCP entries remain untouched.
- Linux MCP is explicitly constrained to `--toolset FIXED`; automatic SSH-key discovery and remote-host access are off unless the user separately opts in.
- The model catalog is live data: filter current Hugging Face results to supported chat/text Unsloth GGUFs, inspect actual artifact sizes and parameter metadata, and retain a dated tested fallback for offline setup.
- Client-side peer consumption is in scope. Making this machine a LAN-serving peer, firewall mutation, key distribution, model-folder synchronization, and distributed model sharding are separate follow-ups.



### Critical risks found during rubber-duck review

- `llmman` chooses an engine/backend for detected hardware; it does **not** choose the model. ChairLift owns recommendation policy.
- Linux NVIDIA acceleration depends on a working container runtime and NVIDIA Container Toolkit; otherwise automatic selection may fall back to CPU. Setup reports the observed backend rather than merely declaring the service healthy.
- Model names do not prove fit or modality. `Flash` can denote a huge MoE model; a recent upstream repository can be safetensors rather than GGUF. Resolution uses Hugging Face metadata and recursive tree sizes.
- `GET /llmman/node` reports the memory llmman uses for routing and is the sizing authority; PCI vendor classification alone is insufficient.
- Jan's Flatpak is currently x86_64-only, and requests from its Tauri origin are not covered by llmman's default localhost CORS set. Both platform and exact-origin behavior must be verified before Ask Bluefin is declared ready.
- `goose-mcp-setup` currently exits successfully without merging an existing config and currently suggests an SSH key. The helper must be hardened upstream; ChairLift must not replace a user's Goose file.
- `linux-mcp-server` is read-only only when restricted to its fixed toolset. It can otherwise execute scripts and can reach hosts available through the user's SSH setup.
- Jan supports custom OpenAI-compatible providers, but zero-touch llmman discovery/configuration needs an upstream-supported contract.
- The current Bluefin menu already has an Ask Bluefin web link and Ctrl+Alt+Backspace currently launches Alpaca. The distro-default change intentionally replaces both.
- `projectbluefin/contribute` currently cannot reach a host loopback llmman daemon from its isolated container and does not forward `OPENAI_BASE_URL`; local-inference donation depends on projectbluefin/contribute#653.



## Success Metrics

- Fresh-install and configured-install paths both complete with observed runtime and model readiness.
- The full benchmark/soak matrix and user-facing screenshots match the shipped experience.

## Non-Goals

- No LAN-serving peer, firewall mutation, key distribution, model sync or sharding.
- No global OMP/Goose migration, new cloud AI default or second privileged service.
