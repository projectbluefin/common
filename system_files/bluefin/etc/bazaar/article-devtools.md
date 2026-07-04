# Developer Experience (DX)

Bluefin's Developer Experience isn't a separate image or a bolt-on flavor — it's an in-place setup flow layered onto your existing workstation with Homebrew and Flatpak. Nothing is baked into the base image; you turn on exactly the tools you need, when you need them.

The primary entrypoint is one command:

```bash
ujust devmode
```

---

## What `ujust devmode` turns on

Running `ujust devmode` opens an interactive picker covering:

- **IDEs and editors** — VS Code, VSCodium, Antigravity, Zed, JetBrains Toolbox, Neovim, Helix, vim, micro
- **Docker and Podman Desktop** — container engines and their GUI companion
- **Virtualization** — virt-manager + QEMU, Lima, incus
- **Developer group setup** — adds you to the required local groups and prompts for a reboot when needed

Pick only what you want installed — everything else stays off your system. Re-run `ujust devmode` any time to add more tools later.

---

## IDEs and editors

### GUI IDEs and casks

| Tool | What it's for | Install |
|---|---|---|
| VS Code | Full-featured GUI IDE with the standard Microsoft extension marketplace. | [Homebrew cask](https://formulae.brew.sh/cask/visual-studio-code-linux) |
| VS Code Insiders | Nightly VS Code build for testing upcoming editor features. | [Homebrew cask](https://formulae.brew.sh/cask/visual-studio-code-linux@insiders) |
| VSCodium | Telemetry-free build of VS Code from open source. | [Homebrew cask](https://formulae.brew.sh/cask/vscodium-linux) |
| Antigravity | Google's AI-native IDE. | [Homebrew cask](https://formulae.brew.sh/cask/antigravity-linux) |
| JetBrains Toolbox | Installer and updater for the full JetBrains IDE lineup (IntelliJ, PyCharm, GoLand, etc). | [Homebrew cask](https://formulae.brew.sh/cask/jetbrains-toolbox-linux) |
| Zed | GPU-accelerated, high-performance native code editor. | `ujust devmode` (experimental tap) |

### Terminal editors

| Tool | What it's for | Install |
|---|---|---|
| Neovim | Extensible Vim-fork with a modern Lua plugin ecosystem. | [Homebrew formula](https://formulae.brew.sh/formula/neovim) |
| Helix | Modal terminal editor with built-in LSP and tree-sitter support. | [Homebrew formula](https://formulae.brew.sh/formula/helix) |
| micro | Simple, modern terminal editor with familiar keybindings. | [Homebrew formula](https://formulae.brew.sh/formula/micro) |
| vim | Classic modal editor, available via `ujust devmode`. | `ujust devmode` |

### VS Code extensions shipped by default

| Extension | What it's for |
|---|---|
| `ms-vscode-remote.remote-containers` | Develop inside a devcontainer without installing tooling on the host. |
| `ms-vscode-remote.remote-ssh` | Edit and run code on a remote machine over SSH. |
| `ms-azuretools.vscode-containers` | Build, manage, and debug containers directly from the editor. |

---

## Containers and virtualization

`ujust devmode` installs the container engine and virtualization stack you pick; the tools below fill out the surrounding workflow.

| Tool | What it's for | Install |
|---|---|---|
| Docker | Container engine plus `docker-compose`, `lazydocker`, and `dive` for image inspection. | `ujust devmode` |
| Podman Desktop | Graphical management tool for containers, pods, and volumes. | **[Install](appstream://io.podman_desktop.PodmanDesktop)** |
| Virtual Machines (virt-manager + QEMU) | Full GUI for creating and managing local VMs. | `ujust devmode` |
| Lima | Lightweight Linux VMs with automatic file sharing and port forwarding, KVM-backed. | `ujust devmode` |
| incus | System container and VM manager (LXD successor). | `ujust devmode` |
| devcontainer CLI | Build and open devcontainers from the command line, matching VS Code's Remote Containers. | Installed automatically by `ujust devmode` |

---

## CLI and CNCF tooling

### Core shell and workstation tools

| Tool | What it's for | Install |
|---|---|---|
| gh | GitHub's official command-line CLI. | [Homebrew formula](https://formulae.brew.sh/formula/gh) |
| atuin | Magical, searchable shell history database. | [Homebrew formula](https://formulae.brew.sh/formula/atuin) |
| bat | A `cat` clone with syntax highlighting and Git integration. | [Homebrew formula](https://formulae.brew.sh/formula/bat) |
| bash-preexec | Bash hook framework used to power shell integrations. | [Homebrew formula](https://formulae.brew.sh/formula/bash-preexec) |
| chezmoi | Securely manage dotfiles across multiple machines. | [Homebrew formula](https://formulae.brew.sh/formula/chezmoi) |
| direnv | Load and unload environment variables per project directory. | [Homebrew formula](https://formulae.brew.sh/formula/direnv) |
| dysk | Fast, colorful disk usage viewer. | [Homebrew formula](https://formulae.brew.sh/formula/dysk) |
| eza | Modern, feature-rich replacement for `ls`. | [Homebrew formula](https://formulae.brew.sh/formula/eza) |
| fd | Simple, fast, user-friendly alternative to `find`. | [Homebrew formula](https://formulae.brew.sh/formula/fd) |
| podman-tui | Terminal UI for managing Podman containers, pods, and images. | [Homebrew formula](https://formulae.brew.sh/formula/podman-tui) |
| ripgrep | High-performance recursive regex search. | [Homebrew formula](https://formulae.brew.sh/formula/ripgrep) |
| tealdeer | Fast Rust implementation of `tldr` community-maintained cheat sheets. | [Homebrew formula](https://formulae.brew.sh/formula/tealdeer) |
| trash-cli | Command-line interface to the freedesktop.org trash can, safer than `rm`. | [Homebrew formula](https://formulae.brew.sh/formula/trash-cli) |
| yq | Portable command-line YAML/XML/JSON processor. | [Homebrew formula](https://formulae.brew.sh/formula/yq) |
| zoxide | Smarter `cd` that learns your most-used directories. | [Homebrew formula](https://formulae.brew.sh/formula/zoxide) |
| mise | Polyglot dev tool, environment variable, and task runner. | [Homebrew formula](https://formulae.brew.sh/formula/mise) |

### Cloud-native and Kubernetes tooling

Graduated CNCF projects:

| Tool | What it's for | Install |
|---|---|---|
| kubectl | Command-line control of Kubernetes clusters. | [Homebrew formula](https://formulae.brew.sh/formula/kubernetes-cli) |
| minikube | Run a single-node local Kubernetes cluster. | [Homebrew formula](https://formulae.brew.sh/formula/minikube) |
| kind | Run local Kubernetes clusters using Docker/Podman container "nodes". | [Homebrew formula](https://formulae.brew.sh/formula/kind) |
| helm | The Kubernetes package manager. | [Homebrew formula](https://formulae.brew.sh/formula/helm) |
| argo | Workflow engine for Kubernetes. | [Homebrew formula](https://formulae.brew.sh/formula/argo) |
| argocd | Declarative GitOps continuous delivery for Kubernetes. | [Homebrew formula](https://formulae.brew.sh/formula/argocd) |
| cilium-cli | Manage and troubleshoot Cilium eBPF networking. | [Homebrew formula](https://formulae.brew.sh/formula/cilium-cli) |
| coredns | Pluggable, extensible DNS server used as the Kubernetes cluster DNS. | [Homebrew formula](https://formulae.brew.sh/formula/coredns) |
| crossplane | Control-plane framework for composing cloud infrastructure as Kubernetes APIs. | [Homebrew formula](https://formulae.brew.sh/formula/crossplane) |
| cri-tools | `crictl` and friends for debugging CRI-compatible container runtimes. | [Homebrew formula](https://formulae.brew.sh/formula/cri-tools) |
| envoy | High-performance edge and service proxy. | [Homebrew formula](https://formulae.brew.sh/formula/envoy) |
| falco | Cloud-native runtime security and threat detection. | [Homebrew formula](https://formulae.brew.sh/formula/falco) |
| flux | GitOps toolkit for continuous delivery on Kubernetes. | [Homebrew formula](https://formulae.brew.sh/formula/flux) |
| harbor-cli | Manage the Harbor container registry from the command line. | [Homebrew formula](https://formulae.brew.sh/formula/harbor-cli) |
| istioctl | Configure and diagnose the Istio service mesh. | [Homebrew formula](https://formulae.brew.sh/formula/istioctl) |
| kn | Command-line client for Knative. | [Homebrew formula](https://formulae.brew.sh/formula/kn) |
| linkerd | Ultralight service mesh for Kubernetes. | [Homebrew formula](https://formulae.brew.sh/formula/linkerd) |
| opa | Open Policy Agent, general-purpose policy engine. | [Homebrew formula](https://formulae.brew.sh/formula/opa) |
| prometheus | Metrics collection and alerting toolkit. | [Homebrew formula](https://formulae.brew.sh/formula/prometheus) |
| vitess | Scalable MySQL-compatible clustering system. | [Homebrew formula](https://formulae.brew.sh/formula/vitess) |
| cmctl | Command-line tool for the cert-manager TLS certificate controller. | [Homebrew formula](https://formulae.brew.sh/formula/cmctl) |
| nerdctl | Docker-compatible CLI for containerd. | [Homebrew formula](https://formulae.brew.sh/formula/nerdctl) |
| etcd | Distributed key-value store backing Kubernetes cluster state. | [Homebrew formula](https://formulae.brew.sh/formula/etcd) |
| dapr-cli | Manage Dapr, the portable distributed-application runtime. | [Homebrew formula](https://formulae.brew.sh/formula/dapr/tap/dapr-cli) |

Incubating and sandbox CNCF projects:

| Tool | What it's for | Install |
|---|---|---|
| ah | Search and publish to Artifact Hub. | [Homebrew formula](https://formulae.brew.sh/formula/artifacthub/cmd/ah) |
| pack | Build OCI images from source using Cloud Native Buildpacks. | [Homebrew formula](https://formulae.brew.sh/formula/buildpacks/tap/pack) |
| c7n | Cloud Custodian, rules engine for cloud resource governance. | [Homebrew formula](https://formulae.brew.sh/formula/c7n) |
| cortex | Horizontally scalable, multi-tenant Prometheus-compatible metrics. | [Homebrew formula](https://formulae.brew.sh/formula/cortex) |
| karmadactl | Manage multi-cluster Kubernetes deployments with Karmada. | [Homebrew formula](https://formulae.brew.sh/formula/karmadactl) |
| kubevela | Application delivery platform built on OAM. | [Homebrew formula](https://formulae.brew.sh/formula/kubevela) |
| virtctl | Manage KubeVirt virtual machines running on Kubernetes. | [Homebrew formula](https://formulae.brew.sh/formula/virtctl) |
| kubescape | Kubernetes security posture and compliance scanner. | [Homebrew formula](https://formulae.brew.sh/formula/kubescape) |
| kyverno | Kubernetes-native policy engine. | [Homebrew formula](https://formulae.brew.sh/formula/kyverno) |
| lima | Linux virtual machines with automatic file sharing and port forwarding. | [Homebrew formula](https://formulae.brew.sh/formula/lima) |
| litmusctl | Manage chaos engineering experiments with LitmusChaos. | [Homebrew formula](https://formulae.brew.sh/formula/litmusctl) |
| nats-server | Lightweight, high-performance messaging system. | [Homebrew formula](https://formulae.brew.sh/formula/nats-server) |
| notation | Sign and verify OCI artifacts with the Notary Project. | [Homebrew formula](https://formulae.brew.sh/formula/notation) |
| openfga | Fine-grained, relationship-based authorization engine. | [Homebrew formula](https://formulae.brew.sh/formula/openfga) |
| opentelemetry-cpp | C++ implementation of the OpenTelemetry observability framework. | [Homebrew formula](https://formulae.brew.sh/formula/opentelemetry-cpp) |
| operator-sdk | Scaffold and build Kubernetes Operators. | [Homebrew formula](https://formulae.brew.sh/formula/operator-sdk) |
| thanos | Highly-available Prometheus setup with long-term storage. | [Homebrew formula](https://formulae.brew.sh/formula/thanos) |
| grpc | High-performance, open-source universal RPC framework. | [Homebrew formula](https://formulae.brew.sh/formula/grpc) |
| wash | Command-line tool for wasmCloud, the WebAssembly application platform. | [Homebrew formula](https://formulae.brew.sh/formula/wasmcloud/wasmcloud/wash) |
| atlantis | Terraform pull-request automation. | [Homebrew formula](https://formulae.brew.sh/formula/atlantis) |
| cdk8s | Define Kubernetes manifests using familiar programming languages. | [Homebrew formula](https://formulae.brew.sh/formula/cdk8s) |
| kwt / kctrl / ytt / kapp / kbld / imgpkg / vendir | The Carvel suite for templating, packaging, and deploying to Kubernetes. | [Homebrew tap](https://formulae.brew.sh/formula/carvel-dev/carvel/kapp) |
| kubectl-cnpg | `kubectl` plugin for the CloudNativePG PostgreSQL operator. | [Homebrew formula](https://formulae.brew.sh/formula/kubectl-cnpg) |
| devspace | Fast iterative development for Kubernetes applications. | [Homebrew formula](https://formulae.brew.sh/formula/devspace) |
| k8sgpt | AI-powered diagnostics for your Kubernetes cluster. | [Homebrew formula](https://formulae.brew.sh/formula/k8sgpt) |
| kcl | Constraint-based configuration and policy language for cloud-native config. | [Homebrew formula](https://formulae.brew.sh/formula/kcl-lang/tap/kcl) |
| kitops | Package and version AI/ML model artifacts as OCI images. | [Homebrew formula](https://formulae.brew.sh/formula/kitops-ml/kitops/kitops) |
| kwctl | Run and manage Kubewarden policies locally. | [Homebrew formula](https://formulae.brew.sh/formula/kwctl) |
| kumactl | Manage the Kuma service mesh. | [Homebrew formula](https://formulae.brew.sh/formula/kumactl) |
| mesheryctl | Manage Meshery, the cloud-native management plane. | [Homebrew formula](https://formulae.brew.sh/formula/mesheryctl) |
| microcks-cli | Mock and test APIs and event-driven services with Microcks. | [Homebrew formula](https://formulae.brew.sh/formula/microcks/tap/microcks-cli) |
| porter | Package and distribute applications as cloud-native bundles. | [Homebrew formula](https://formulae.brew.sh/formula/porter) |
| telepresence-oss | Run a local service as if it were inside a remote Kubernetes cluster. | [Homebrew formula](https://formulae.brew.sh/formula/telepresenceio/telepresence/telepresence-oss) |
| tremor-runtime | Event-processing system for unstructured data. | [Homebrew formula](https://formulae.brew.sh/formula/tremor-runtime) |
| wasmedge | Lightweight, high-performance WebAssembly runtime. | [Homebrew formula](https://formulae.brew.sh/formula/wasmedge) |
| k0sctl | Bootstrap and manage k0s Kubernetes clusters. | [Homebrew formula](https://formulae.brew.sh/formula/k0sproject/tap/k0sctl) |
| k3d | Run lightweight k3s Kubernetes clusters in Docker. | [Homebrew formula](https://formulae.brew.sh/formula/k3d) |
| ko | Build and deploy Go containers without writing a Dockerfile. | [Homebrew formula](https://formulae.brew.sh/formula/ko) |
| kpt | Package, customize, and apply Kubernetes configuration as data. | [Homebrew formula](https://formulae.brew.sh/formula/kptdev/kpt/kpt) |

Graphical Kubernetes tools:

| Tool | What it's for | Install |
|---|---|---|
| Headlamp | Extensible, easy-to-use dashboard for Kubernetes clusters. | **[Install](appstream://io.kinvolk.Headlamp)** |
| OpenLens | Full-featured desktop IDE for Kubernetes workflows. | **[Install](appstream://dev.k8slens.OpenLens)** |

---

## Recommended workflows

- **Local container development** — `ujust devmode` → Docker or Podman Desktop, then `devcontainer up` from your project directory.
- **Remote development containers** — install the `ms-vscode-remote.remote-containers` and `ms-vscode-remote.remote-ssh` VS Code extensions (on by default) and open a folder over SSH or in a devcontainer.
- **Kubernetes cluster work** — `kind` or `minikube` for local clusters, `kubectl` + `helm` for day-to-day operations, `k9s` or Headlamp/OpenLens when you want a visual view.
- **Virtualization and local VM work** — `ujust devmode` → virt-manager + QEMU for full VMs, or Lima for lightweight KVM-backed Linux VMs.
- **General shell productivity** — `mise` for per-project runtime versions, `atuin` for searchable shell history, `eza`/`bat`/`fd`/`ripgrep` as everyday replacements for `ls`/`cat`/`find`/`grep`.
