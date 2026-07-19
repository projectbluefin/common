# Developer Experience Portal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Bazaar Developer Experience page into a working Markdown-first portal centered on `ujust devmode`, Bluefin IDE/editor installs, container tooling, and practical command-line workflows.

**Architecture:** Replace the current raw-HTML article with a source-backed Markdown document. Keep the page reliable by following the same heading/table/list pattern as the other working Bazaar articles, and keep it accurate by sourcing tool names from `system.just` and the Brewfiles already shipped in the image.

**Tech Stack:** Bazaar curated article Markdown, Homebrew Brewfiles, `just`, `pytest`, ripgrep

## Global Constraints

- Use `ujust devmode` as the primary setup entrypoint.
- Prefer Markdown tables and short lists over raw HTML layouts.
- Do not mention `bctl --screen developer` as the primary entrypoint.
- Do not describe DX as a retired `-dx` image flow.
- Do not leave placeholders, lorem ipsum, or speculative copy.
- Keep descriptions functional and source-backed.
- Source tool names from `system_files/bluefin/usr/share/ublue-os/just/system.just`, `system_files/shared/usr/share/ublue-os/homebrew/ide.Brewfile`, `system_files/shared/usr/share/ublue-os/homebrew/cli.Brewfile`, and `system_files/shared/usr/share/ublue-os/homebrew/cncf.Brewfile`.

---

## File Structure

- `system_files/bluefin/etc/bazaar/article-devtools.md`
  - The DX portal article shown inside Bazaar.
  - This file should become a pure Markdown article with source-backed tables and commands.
- `docs/skills/bazaar.md`
  - Bazaar authoring and validation guidance.
  - Update this file only if the article rewrite confirms a reusable “prefer Markdown tables over raw HTML card walls” rule.
- `tests/test_curated_config.py`
  - Existing Bazaar config regression check.
  - This file is not expected to change, but it is the existing targeted validation command named by the repo skill.

### Task 1: Rebuild the article skeleton, entrypoint, IDEs, and containers

**Files:**
- Modify: `system_files/bluefin/etc/bazaar/article-devtools.md`
- Test: shell checks run from the repo root against `system_files/bluefin/etc/bazaar/article-devtools.md`

**Interfaces:**
- Consumes: tool names and install surfaces from `system_files/bluefin/usr/share/ublue-os/just/system.just:45-173` and `system_files/shared/usr/share/ublue-os/homebrew/ide.Brewfile:1-14`
- Produces: the opening half of `article-devtools.md` with the exact headings `## Turn on Developer Mode`, `## IDEs and Editors`, and `## Containers and Virtualization`

- [ ] **Step 1: Write the failing shell check for the first half of the article**

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("system_files/bluefin/etc/bazaar/article-devtools.md")
text = path.read_text(encoding="utf-8")

required = [
    "## Turn on Developer Mode",
    "## IDEs and Editors",
    "## Containers and Virtualization",
    "ujust devmode",
    "| Tool | What it is for | Install |",
    "VS Code Insiders",
    "JetBrains Toolbox",
    "Zed",
    "devcontainer CLI",
    "Podman Desktop",
    "Virtual Machines (virt-manager + QEMU)",
]

missing = [item for item in required if item not in text]
forbidden = ["<div style=", "system-dx-flatpaks.Brewfile"]
present_forbidden = [item for item in forbidden if item in text]

assert not present_forbidden, f"Forbidden legacy content still present: {present_forbidden}"
assert not missing, f"Missing required portal content: {missing}"
print("DX article first-half portal checks passed")
PY
```

- [ ] **Step 2: Run the check to verify it fails on the current article**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("system_files/bluefin/etc/bazaar/article-devtools.md")
text = path.read_text(encoding="utf-8")

required = [
    "## Turn on Developer Mode",
    "## IDEs and Editors",
    "## Containers and Virtualization",
    "ujust devmode",
    "| Tool | What it is for | Install |",
    "VS Code Insiders",
    "JetBrains Toolbox",
    "Zed",
    "devcontainer CLI",
    "Podman Desktop",
    "Virtual Machines (virt-manager + QEMU)",
]

missing = [item for item in required if item not in text]
forbidden = ["<div style=", "system-dx-flatpaks.Brewfile"]
present_forbidden = [item for item in forbidden if item in text]

assert not present_forbidden, f"Forbidden legacy content still present: {present_forbidden}"
assert not missing, f"Missing required portal content: {missing}"
print("DX article first-half portal checks passed")
PY
```

Expected: FAIL with both of these signals:

- `Forbidden legacy content still present`
- `Missing required portal content`

- [ ] **Step 3: Replace the raw-HTML opening with the Markdown portal skeleton**

Overwrite the beginning of `system_files/bluefin/etc/bazaar/article-devtools.md` so it starts with this exact Markdown structure, then continue the file with the later sections from Task 2:

````md
# Developer Experience (DX)

Project Bluefin's developer experience is an in-place setup flow. Start with `ujust devmode` to turn on the editor, container, and virtualization tools that make Bluefin a practical workstation for daily engineering work.

---

## Turn on Developer Mode

Run:

```bash
ujust devmode
```

Developer Mode is the front door for the tools Bluefin wires together on purpose:

- IDEs and editors
- Docker and Podman Desktop
- Virtual Machines, Lima, and incus
- `devcontainer` CLI
- group setup for `docker`, `libvirt`, `incus-admin`, and `dialout`

Reboot after setup so the new group membership takes effect.

## IDEs and Editors

### GUI IDEs and casks

| Tool | What it is for | Install |
| --- | --- | --- |
| VS Code | Microsoft VS Code packaged through `ublue-os/tap` for Bluefin developer workflows. | `ujust devmode` or `brew install --cask ublue-os/tap/visual-studio-code-linux` |
| VS Code Insiders | Preview build of VS Code from the same Bluefin tap. | `brew install --cask ublue-os/tap/visual-studio-code-linux@insiders` |
| VSCodium | Telemetry-free VS Code build packaged in the Bluefin tap. | `ujust devmode` or `brew install --cask ublue-os/tap/vscodium-linux` |
| Antigravity | Bluefin's preferred AI-native editor shipped through the Bluefin tap. | `ujust devmode` or `brew install --cask ublue-os/tap/antigravity-linux` |
| JetBrains Toolbox | JetBrains launcher for IntelliJ, PyCharm, GoLand, and the rest of the JetBrains stack. | `ujust devmode` or `brew install --cask ublue-os/tap/jetbrains-toolbox-linux` |
| Zed | Experimental high-speed editor available through `ublue-os/experimental-tap`. | `ujust devmode` or `brew install --cask ublue-os/experimental-tap/zed-linux` |

### Terminal editors

| Tool | What it is for | Install |
| --- | --- | --- |
| Neovim | Extensible modal editor for terminal-first development. | `ujust devmode` or `brew install nvim` |
| Helix | Modal editor with tree-sitter and LSP support out of the box. | `ujust devmode` or `brew install helix` |
| vim | Classic Vim for environments where you want the standard tool. | `ujust devmode` or `brew install vim` |
| micro | Simple terminal editor with modern defaults. | `ujust devmode` or `brew install micro` |

### VS Code defaults shipped by Bluefin

| Extension | What it is for |
| --- | --- |
| `ms-vscode-remote.remote-containers` | Open a project directly inside a development container. |
| `ms-vscode-remote.remote-ssh` | Develop against a remote machine over SSH. |
| `ms-azuretools.vscode-containers` | Build, inspect, and run container workloads from inside VS Code. |

## Containers and Virtualization

| Tool | What it is for | Install |
| --- | --- | --- |
| `devcontainer` CLI | Build and open Development Containers from any editor. | `ujust devmode` or `brew install devcontainer` |
| Docker | Docker CLI plus Compose, lazydocker, and dive for container workflows. | `ujust devmode` |
| Podman Desktop | Graphical desktop for containers, pods, and volumes. | `ujust devmode` or **[Install](appstream://io.podman_desktop.PodmanDesktop)** |
| Virtual Machines (virt-manager + QEMU) | Native libvirt virtual machine management with the QEMU extension. | `ujust devmode` |
| Lima | Lightweight local Linux VMs with sensible developer defaults. | `ujust devmode` or `brew install lima` |
| incus | System containers and lightweight VM workflows. | `ujust devmode` or `brew install incus` |
````

Notes for the edit:

- Delete the existing raw HTML card walls instead of trying to salvage them.
- Keep `ujust devmode` as the first command users see.
- Keep the language short and practical.

- [ ] **Step 4: Run the first-half check and verify it passes**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("system_files/bluefin/etc/bazaar/article-devtools.md")
text = path.read_text(encoding="utf-8")

required = [
    "## Turn on Developer Mode",
    "## IDEs and Editors",
    "## Containers and Virtualization",
    "ujust devmode",
    "| Tool | What it is for | Install |",
    "VS Code Insiders",
    "JetBrains Toolbox",
    "Zed",
    "devcontainer CLI",
    "Podman Desktop",
    "Virtual Machines (virt-manager + QEMU)",
]

missing = [item for item in required if item not in text]
forbidden = ["<div style=", "system-dx-flatpaks.Brewfile"]
present_forbidden = [item for item in forbidden if item in text]

assert not present_forbidden, f"Forbidden legacy content still present: {present_forbidden}"
assert not missing, f"Missing required portal content: {missing}"
print("DX article first-half portal checks passed")
PY
```

Expected: PASS with `DX article first-half portal checks passed`

- [ ] **Step 5: Commit the first-half rewrite**

```bash
git add system_files/bluefin/etc/bazaar/article-devtools.md
git commit -m "docs(bazaar): rebuild dx portal opening"
```

### Task 2: Add the CLI, cloud-native, and workflow sections and remove all placeholder copy

**Files:**
- Modify: `system_files/bluefin/etc/bazaar/article-devtools.md`
- Test: shell checks run from the repo root against `system_files/bluefin/etc/bazaar/article-devtools.md`

**Interfaces:**
- Consumes: the exact headings produced by Task 1 plus tool names from `system_files/shared/usr/share/ublue-os/homebrew/cli.Brewfile:1-17` and `system_files/shared/usr/share/ublue-os/homebrew/cncf.Brewfile:1-304`
- Produces: the completed portal article with `## Command-Line Utilities`, `## Cloud-Native Tooling`, and `## Recommended Workflows`

- [ ] **Step 1: Write the failing shell check for the second half of the article**

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("system_files/bluefin/etc/bazaar/article-devtools.md")
text = path.read_text(encoding="utf-8")

required = [
    "## Command-Line Utilities",
    "## Cloud-Native Tooling",
    "## Recommended Workflows",
    "brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile",
    "brew bundle --file=/usr/share/ublue-os/homebrew/cncf.Brewfile",
    "| `gh` |",
    "| `kubectl` |",
    "| `Headlamp` |",
]

missing = [item for item in required if item not in text]
assert "Lorem ipsum" not in text, "Placeholder copy still present"
assert "Project Bluefin's **Developer Experience (DX)** is crafted specifically" not in text, "Legacy marketing ending still present"
assert not missing, f"Missing second-half portal content: {missing}"
print("DX article second-half portal checks passed")
PY
```

- [ ] **Step 2: Run the check to verify it fails before the second-half rewrite**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("system_files/bluefin/etc/bazaar/article-devtools.md")
text = path.read_text(encoding="utf-8")

required = [
    "## Command-Line Utilities",
    "## Cloud-Native Tooling",
    "## Recommended Workflows",
    "brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile",
    "brew bundle --file=/usr/share/ublue-os/homebrew/cncf.Brewfile",
    "| `gh` |",
    "| `kubectl` |",
    "| `Headlamp` |",
]

missing = [item for item in required if item not in text]
assert "Lorem ipsum" not in text, "Placeholder copy still present"
assert "Project Bluefin's **Developer Experience (DX)** is crafted specifically" not in text, "Legacy marketing ending still present"
assert not missing, f"Missing second-half portal content: {missing}"
print("DX article second-half portal checks passed")
PY
```

Expected: FAIL with one or more of these signals:

- `Placeholder copy still present`
- `Legacy marketing ending still present`
- `Missing second-half portal content`

- [ ] **Step 3: Finish the article with source-backed CLI, cloud-native, and workflow sections**

Append or replace the bottom half of `system_files/bluefin/etc/bazaar/article-devtools.md` with this exact structure after the containers section:

````md
## Command-Line Utilities

Install the core workstation bundle with:

```bash
brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile
```

| Tool | What it is for | Install |
| --- | --- | --- |
| `atuin` | Shell history search and sync with a modern UI. | `brew install atuin` |
| `bat` | `cat` with syntax highlighting and paging defaults that are easier to read. | `brew install bat` |
| `bash-preexec` | Bash hook support for prompt-aware tooling. | `brew install bash-preexec` |
| `chezmoi` | Dotfile management across machines. | `brew install chezmoi` |
| `direnv` | Per-directory environment loading and unloading. | `brew install direnv` |
| `dysk` | Fast disk usage inspection from the terminal. | `brew install dysk` |
| `eza` | Modern `ls` replacement with better defaults. | `brew install eza` |
| `fd` | Fast, ergonomic file finder. | `brew install fd` |
| `gh` | GitHub CLI for issues, PRs, and repo automation. | `brew install gh` |
| `podman-tui` | Terminal UI for Podman workloads. | `brew install podman-tui` |
| `ripgrep` | High-speed recursive search. | `brew install ripgrep` |
| `tealdeer` | Fast local `tldr` client for command examples. | `brew install tealdeer` |
| `trash-cli` | Safe trash commands instead of immediate delete. | `brew install trash-cli` |
| `yq` | YAML, JSON, and XML processing from the shell. | `brew install yq` |
| `zoxide` | Smarter directory jumping based on frequency and recency. | `brew install zoxide` |
| `mise` | Runtime, task, and environment manager for polyglot projects. | `brew install mise` |

## Cloud-Native Tooling

Install the full cloud-native bundle with:

```bash
brew bundle --file=/usr/share/ublue-os/homebrew/cncf.Brewfile
```

Install the desktop companions with:

```bash
flatpak install --system flathub io.kinvolk.Headlamp dev.k8slens.OpenLens io.podman_desktop.PodmanDesktop
```

### Core cluster tools

| Tool | What it is for | Install |
| --- | --- | --- |
| `kubectl` | Talk to Kubernetes clusters directly. | `brew install kubernetes-cli` |
| `helm` | Install and manage Kubernetes packages. | `brew install helm` |
| `kind` | Spin up local Kubernetes clusters inside containers. | `brew install kind` |
| `minikube` | Single-node local cluster for testing and learning. | `brew install minikube` |
| `k3d` | Quick local k3s clusters inside Docker. | `brew install k3d` |
| `virtctl` | Operate KubeVirt virtual machines from the CLI. | `brew install virtctl` |
| `devspace` | Inner-loop Kubernetes development and sync. | `brew install devspace` |
| `k9s` | Terminal cluster browser already called out in the workflow section. | `brew install k9s` |

### Delivery, packaging, and platform APIs

| Tool | What it is for | Install |
| --- | --- | --- |
| `argo` | Run and inspect Argo Workflows. | `brew install argo` |
| `argocd` | Operate Argo CD deployments and syncs. | `brew install argocd` |
| `flux` | GitOps delivery and reconciliation. | `brew install flux` |
| `pack` | Build OCI images from Cloud Native Buildpacks. | `brew install buildpacks/tap/pack` |
| `operator-sdk` | Scaffold and maintain Kubernetes operators. | `brew install operator-sdk` |
| `ko` | Build and publish Go container images without a Dockerfile. | `brew install ko` |
| `kpt` | Package-driven Kubernetes configuration management. | `brew install kptdev/kpt/kpt` |
| `porter` | Bundle and run CNAB application packages. | `brew install porter` |
| `crossplane` | Compose and manage cloud resources through Kubernetes APIs. | `brew install crossplane` |
| `kubevela` | Application delivery platform built on Kubernetes. | `brew install kubevela` |

### Security, policy, and observability

| Tool | What it is for | Install |
| --- | --- | --- |
| `cilium-cli` | Operate and verify Cilium networking. | `brew install cilium-cli` |
| `falco` | Runtime threat detection for container workloads. | `brew install falco` |
| `kubescape` | Kubernetes posture and risk scanning. | `brew install kubescape` |
| `kyverno` | Policy-as-code for Kubernetes resources. | `brew install kyverno` |
| `opa` | General policy engine for platform rules. | `brew install opa` |
| `prometheus` | Metrics collection and local Prometheus work. | `brew install prometheus` |
| `k8sgpt` | AI-assisted cluster diagnostics. | `brew install k8sgpt` |

### Desktop companions

| Tool | What it is for | Install |
| --- | --- | --- |
| `Headlamp` | Kubernetes UI for cluster browsing and day-to-day ops. | **[Install](appstream://io.kinvolk.Headlamp)** |
| `OpenLens` | Full desktop Kubernetes IDE. | **[Install](appstream://dev.k8slens.OpenLens)** |
| `Podman Desktop` | Desktop container manager that pairs well with the CLI tools above. | **[Install](appstream://io.podman_desktop.PodmanDesktop)** |

## Recommended Workflows

### Local container work

- Start with `ujust devmode` for Docker, Podman Desktop, and `devcontainer`.
- Use Docker when a project expects the Docker CLI exactly.
- Use Podman Desktop when you want a graphical view of containers, images, and volumes.

### Development containers

- Use the shipped `devcontainer` CLI with VS Code, VSCodium, or Antigravity.
- Keep the editor on the host and the toolchain inside the container when a repo already has a `.devcontainer/` definition.

### Kubernetes work

- Use `kubectl`, `helm`, and `k9s` for the daily loop.
- Add `Headlamp` or `OpenLens` when you want a GUI.
- Use `kind`, `minikube`, or `k3d` for local clusters.

### Virtual machines and system containers

- Use Virtual Machines when you need a full libvirt guest.
- Use Lima for lightweight local Linux environments.
- Use incus when the workflow wants system containers or lightweight VM orchestration.

### Shell productivity

- Use `ripgrep`, `fd`, `eza`, and `bat` as the default search-and-inspect toolkit.
- Use `direnv`, `mise`, and `chezmoi` to keep project environments repeatable.
````

Notes for the edit:

- Delete the trailing placeholder paragraphs entirely.
- Keep the `cli.Brewfile` section exhaustive for the uncommented formulas in that file.
- Keep the `cncf.Brewfile` section focused on the developer-facing tools above plus the bundle install command; do not paste the entire Brewfile into the article.

- [ ] **Step 4: Run the second-half check and verify it passes**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("system_files/bluefin/etc/bazaar/article-devtools.md")
text = path.read_text(encoding="utf-8")

required = [
    "## Command-Line Utilities",
    "## Cloud-Native Tooling",
    "## Recommended Workflows",
    "brew bundle --file=/usr/share/ublue-os/homebrew/cli.Brewfile",
    "brew bundle --file=/usr/share/ublue-os/homebrew/cncf.Brewfile",
    "| `gh` |",
    "| `kubectl` |",
    "| `Headlamp` |",
]

missing = [item for item in required if item not in text]
assert "Lorem ipsum" not in text, "Placeholder copy still present"
assert "Project Bluefin's **Developer Experience (DX)** is crafted specifically" not in text, "Legacy marketing ending still present"
assert not missing, f"Missing second-half portal content: {missing}"
print("DX article second-half portal checks passed")
PY
```

Expected: PASS with `DX article second-half portal checks passed`

- [ ] **Step 5: Commit the completed portal article**

```bash
git add system_files/bluefin/etc/bazaar/article-devtools.md
git commit -m "docs(bazaar): rebuild developer experience portal"
```

### Task 3: Write back the Bazaar article authoring rule and run the final checks

**Files:**
- Modify: `docs/skills/bazaar.md`
- Modify: `system_files/bluefin/etc/bazaar/article-devtools.md`
- Test: `tests/test_curated_config.py`

**Interfaces:**
- Consumes: the completed DX portal article from Task 2
- Produces: a reusable Bazaar skill note that future agents can follow when writing portal-style curated articles

- [ ] **Step 1: Write the failing check for the skill update**

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("docs/skills/bazaar.md")
text = path.read_text(encoding="utf-8")

required = [
    "Curated article markdown should prefer plain Markdown headings, tables, and lists over large raw HTML card layouts.",
    "Editing curated content without local preview causes UI regressions to slip through.",
]

missing = [item for item in required if item not in text]
assert not missing, f"Missing Bazaar skill guidance: {missing}"
print("Bazaar skill article-guidance checks passed")
PY
```

- [ ] **Step 2: Run the check to verify it fails before the skill update**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("docs/skills/bazaar.md")
text = path.read_text(encoding="utf-8")

required = [
    "Curated article markdown should prefer plain Markdown headings, tables, and lists over large raw HTML card layouts.",
    "Editing curated content without local preview causes UI regressions to slip through.",
]

missing = [item for item in required if item not in text]
assert not missing, f"Missing Bazaar skill guidance: {missing}"
print("Bazaar skill article-guidance checks passed")
PY
```

Expected: FAIL with `Missing Bazaar skill guidance`

- [ ] **Step 3: Add the reusable Bazaar article-authoring note**

Add this bullet under `## Common pitfalls` in `docs/skills/bazaar.md`:

```md
- Curated article markdown should prefer plain Markdown headings, tables, and lists over large raw HTML card layouts. The raw-HTML approach used in the old Developer Experience page proved brittle and can fail to render cleanly in Bazaar.
```

Add this checklist item under `## Verification` in `docs/skills/bazaar.md`:

```md
- [ ] Curated article pages use Markdown-first structure (headings/tables/lists) instead of large inline HTML card walls unless Bazaar rendering has been verified locally for that exact layout.
```

- [ ] **Step 4: Run the targeted checks and the existing repo validations**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("docs/skills/bazaar.md")
text = path.read_text(encoding="utf-8")

required = [
    "Curated article markdown should prefer plain Markdown headings, tables, and lists over large raw HTML card layouts.",
    "Curated article pages use Markdown-first structure (headings/tables/lists) instead of large inline HTML card walls unless Bazaar rendering has been verified locally for that exact layout.",
]

missing = [item for item in required if item not in text]
assert not missing, f"Missing Bazaar skill guidance: {missing}"
print("Bazaar skill article-guidance checks passed")
PY

python3 -m pytest tests/test_curated_config.py -v
just check
pre-commit run --files system_files/bluefin/etc/bazaar/article-devtools.md docs/skills/bazaar.md
```

Expected:

- `Bazaar skill article-guidance checks passed`
- `tests/test_curated_config.py` passes
- `just check` passes
- `pre-commit` passes for the changed files

- [ ] **Step 5: Commit the skill write-back and validation-friendly final state**

```bash
git add system_files/bluefin/etc/bazaar/article-devtools.md docs/skills/bazaar.md
git commit -m "docs(skills): add bazaar article authoring rule"
```

## Self-Review

- **Spec coverage:** Task 1 covers the `ujust devmode` entrypoint, IDE/editor inventory, and containers/virtualization. Task 2 covers CLI, cloud-native tooling, workflow guidance, and removal of stale copy. Task 3 covers the required skill write-back and validation pass.
- **Placeholder scan:** This plan contains exact file paths, exact commands, and exact Markdown to add. No `TODO`, `TBD`, or “similar to” shortcuts remain.
- **Type consistency:** The produced headings and files are named consistently across tasks: `## Turn on Developer Mode`, `## IDEs and Editors`, `## Containers and Virtualization`, `## Command-Line Utilities`, `## Cloud-Native Tooling`, and `## Recommended Workflows`.
