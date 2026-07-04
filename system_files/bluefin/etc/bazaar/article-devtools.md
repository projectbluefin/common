# Developer Experience (DX)

Bluefin's Developer Experience is not a separate image or a bolt-on flavor — it's an in-place setup flow layered onto your existing workstation. The operating system and developer environment are deliberately kept separate: tooling isn't installed on the host, it's containerized, run in a virtual machine, or scoped to your home directory via Homebrew.

## The cloud-native development approach

Bluefin goes "all in" on cloud-native development, used differently than a traditional distribution such as Ubuntu:

- Development happens in containers — [Devcontainers](https://containers.dev/) with VS Code, JetBrains, or Neovim; [Podman Desktop](https://podman-desktop.io/docs/intro) for a graphical container workflow; or `podman`/`docker` directly from the command line.
- Command-line applications are installed with [Homebrew](https://brew.sh).
- Preconfigured ad-hoc containers for Ubuntu, Fedora, and Wolfi are included — use whichever distribution you want for a "pet container".

There is no equivalent to `apt install php` on Bluefin: development happens in `podman` or `docker` directly via an IDE, and command-line ecosystems (Homebrew, `uv`, `mise`) are used instead of one system package manager trying to do everything.

## Enabling Developer Mode

Turning on Developer Mode is one command:

```bash
ujust devmode
```

This opens an interactive picker covering IDEs and editors, Docker and Podman Desktop, virtualization (virt-manager + QEMU, Lima, incus), and adds your user to any groups the selected tools require — then prompts for a reboot when needed. Re-run `ujust devmode` any time to add more tools later.

---

## IDEs and editors

### GUI IDEs and casks

Click a tile to install. These redirect to the Homebrew build behind the scenes because none of them officially support Flatpak — Bazaar shows a one-time confirmation dialog, then runs the install in a terminal.

![GUI IDEs](appstream://com.visualstudio.code,appstream://com.vscodium.codium,appstream://dev.zed.Zed,appstream://com.jetbrains.PyCharm-Community)

VS Code is the recommended starting point — the Dev Containers extension is preinstalled. VS Code Insiders (nightly builds) and Antigravity (Google's AI-native IDE) don't have a Flatpak/Homebrew hook wired up yet; install them with `ujust devmode`.

### Terminal editors

![Terminal editors](appstream://io.neovim.nvim,appstream://com.helix_editor.Helix,appstream://org.vim.Vim,appstream://io.github.zyedidia.micro)

### VS Code extensions shipped by default

| Extension | What it's for |
|---|---|
| `ms-vscode-remote.remote-containers` | Develop inside a devcontainer without installing tooling on the host. |
| `ms-vscode-remote.remote-ssh` | Edit and run code on a remote machine over SSH. |
| `ms-azuretools.vscode-containers` | Build, manage, and debug containers directly from the editor. |

---

## Containers and virtualization

Visual Studio Code with Docker is the recommended starting point if you're new to containerized development — VS Code ships with the Dev Containers extension already installed, and the current Docker Engine is set up as the default container runtime.

To switch the Dev Containers extension to Podman instead of Docker, add these settings to VS Code:

```json
"dev.containers.dockerComposePath": "podman-compose"
"dev.containers.dockerPath": "podman"
"dev.containers.dockerSocketPath": "/run/user/1000/podman/podman.sock"
```

![Podman Desktop and Virtual Machines](appstream://io.podman_desktop.PodmanDesktop,appstream://org.virt_manager.virt-manager)

| Tool | What it's for | Install |
|---|---|---|
| Docker | Container engine plus `docker-compose`, `lazydocker`, and `dive` for image inspection. | `ujust devmode` |
| Lima | Lightweight Linux VMs with automatic file sharing and port forwarding, KVM-backed. | `ujust devmode` |
| incus | System container and VM manager (LXD successor). | `ujust devmode` |
| devcontainer CLI | Build and open devcontainers from the command line, matching VS Code's Remote Containers. | Installed automatically by `ujust devmode` |

**SELinux troubleshooting:** if a devcontainer fails to start with SELinux access errors (check `ausearch -m avc -ts recent`), run `restorecon -R -v $HOME/.local/share` (and `restorecon -R -v /path/to/your/project` for volume mount errors).

---

## CLI and CNCF tooling

### Core shell and workstation tools

Enabled as part of the Bluefin CLI terminal experience:

```bash
ujust bluefin-cli
```

| Tool | What it's for | Install |
|---|---|---|
| gh | GitHub's official command-line CLI. | `ujust bluefin-cli` |
| atuin | Magical, searchable shell history database. | `ujust bluefin-cli` |
| bat | A `cat` clone with syntax highlighting and Git integration. | `ujust bluefin-cli` |
| bash-preexec | Bash hook framework used to power shell integrations. | `ujust bluefin-cli` |
| chezmoi | Securely manage dotfiles across multiple machines. | `ujust bluefin-cli` |
| direnv | Load and unload environment variables per project directory. | `ujust bluefin-cli` |
| dysk | Fast, colorful disk usage viewer. | `ujust bluefin-cli` |
| eza | Modern, feature-rich replacement for `ls`. | `ujust bluefin-cli` |
| fd | Simple, fast, user-friendly alternative to `find`. | `ujust bluefin-cli` |
| podman-tui | Terminal UI for managing Podman containers, pods, and images. | `ujust bluefin-cli` |
| ripgrep | High-performance recursive regex search. | `ujust bluefin-cli` |
| tealdeer | Fast Rust implementation of `tldr` community-maintained cheat sheets. | `ujust bluefin-cli` |
| trash-cli | Command-line interface to the freedesktop.org trash can, safer than `rm`. | `ujust bluefin-cli` |
| yq | Portable command-line YAML/XML/JSON processor. | `ujust bluefin-cli` |
| zoxide | Smarter `cd` that learns your most-used directories. | `ujust bluefin-cli` |
| mise | Polyglot dev tool, environment variable, and task runner — install per-project tool versions via `mise.toml`. | `ujust bluefin-cli` |

### Cloud-native and Kubernetes tooling

The full [Cloud Native Computing Foundation](https://landscape.cncf.io/) landscape — 89 formulas across graduated, incubating, and sandbox projects — installs as one bundle:

```bash
ujust cncf
```

Graduated CNCF projects:

| Tool | What it's for | Install |
|---|---|---|
| kubectl | Command-line control of Kubernetes clusters. | `ujust cncf` |
| minikube | Run a single-node local Kubernetes cluster. | `ujust cncf` |
| kind | Run local Kubernetes clusters using Docker/Podman container "nodes". | `ujust cncf` |
| helm | The Kubernetes package manager. | `ujust cncf` |
| argo | Workflow engine for Kubernetes. | `ujust cncf` |
| argocd | Declarative GitOps continuous delivery for Kubernetes. | `ujust cncf` |
| cilium-cli | Manage and troubleshoot Cilium eBPF networking. | `ujust cncf` |
| coredns | Pluggable, extensible DNS server used as the Kubernetes cluster DNS. | `ujust cncf` |
| crossplane | Control-plane framework for composing cloud infrastructure as Kubernetes APIs. | `ujust cncf` |
| cri-tools | `crictl` and friends for debugging CRI-compatible container runtimes. | `ujust cncf` |
| envoy | High-performance edge and service proxy. | `ujust cncf` |
| falco | Cloud-native runtime security and threat detection. | `ujust cncf` |
| flux | GitOps toolkit for continuous delivery on Kubernetes. | `ujust cncf` |
| harbor-cli | Manage the Harbor container registry from the command line. | `ujust cncf` |
| istioctl | Configure and diagnose the Istio service mesh. | `ujust cncf` |
| kn | Command-line client for Knative. | `ujust cncf` |
| linkerd | Ultralight service mesh for Kubernetes. | `ujust cncf` |
| opa | Open Policy Agent, general-purpose policy engine. | `ujust cncf` |
| prometheus | Metrics collection and alerting toolkit. | `ujust cncf` |
| vitess | Scalable MySQL-compatible clustering system. | `ujust cncf` |
| cmctl | Command-line tool for the cert-manager TLS certificate controller. | `ujust cncf` |
| nerdctl | Docker-compatible CLI for containerd. | `ujust cncf` |
| etcd | Distributed key-value store backing Kubernetes cluster state. | `ujust cncf` |
| dapr-cli | Manage Dapr, the portable distributed-application runtime. | `ujust cncf` |

Incubating and sandbox CNCF projects:

| Tool | What it's for | Install |
|---|---|---|
| ah | Search and publish to Artifact Hub. | `ujust cncf` |
| pack | Build OCI images from source using Cloud Native Buildpacks. | `ujust cncf` |
| c7n | Cloud Custodian, rules engine for cloud resource governance. | `ujust cncf` |
| cortex | Horizontally scalable, multi-tenant Prometheus-compatible metrics. | `ujust cncf` |
| karmadactl | Manage multi-cluster Kubernetes deployments with Karmada. | `ujust cncf` |
| kubevela | Application delivery platform built on OAM. | `ujust cncf` |
| virtctl | Manage KubeVirt virtual machines running on Kubernetes. | `ujust cncf` |
| kubescape | Kubernetes security posture and compliance scanner. | `ujust cncf` |
| kyverno | Kubernetes-native policy engine. | `ujust cncf` |
| lima | Linux virtual machines with automatic file sharing and port forwarding. | `ujust cncf` |
| litmusctl | Manage chaos engineering experiments with LitmusChaos. | `ujust cncf` |
| nats-server | Lightweight, high-performance messaging system. | `ujust cncf` |
| notation | Sign and verify OCI artifacts with the Notary Project. | `ujust cncf` |
| openfga | Fine-grained, relationship-based authorization engine. | `ujust cncf` |
| opentelemetry-cpp | C++ implementation of the OpenTelemetry observability framework. | `ujust cncf` |
| operator-sdk | Scaffold and build Kubernetes Operators. | `ujust cncf` |
| thanos | Highly-available Prometheus setup with long-term storage. | `ujust cncf` |
| grpc | High-performance, open-source universal RPC framework. | `ujust cncf` |
| wash | Command-line tool for wasmCloud, the WebAssembly application platform. | `ujust cncf` |
| atlantis | Terraform pull-request automation. | `ujust cncf` |
| cdk8s | Define Kubernetes manifests using familiar programming languages. | `ujust cncf` |
| kwt / kctrl / ytt / kapp / kbld / imgpkg / vendir | The Carvel suite for templating, packaging, and deploying to Kubernetes. | `ujust cncf` |
| kubectl-cnpg | `kubectl` plugin for the CloudNativePG PostgreSQL operator. | `ujust cncf` |
| devspace | Fast iterative development for Kubernetes applications. | `ujust cncf` |
| k8sgpt | AI-powered diagnostics for your Kubernetes cluster. | `ujust cncf` |
| kcl | Constraint-based configuration and policy language for cloud-native config. | `ujust cncf` |
| kitops | Package and version AI/ML model artifacts as OCI images. | `ujust cncf` |
| kwctl | Run and manage Kubewarden policies locally. | `ujust cncf` |
| kumactl | Manage the Kuma service mesh. | `ujust cncf` |
| mesheryctl | Manage Meshery, the cloud-native management plane. | `ujust cncf` |
| microcks-cli | Mock and test APIs and event-driven services with Microcks. | `ujust cncf` |
| porter | Package and distribute applications as cloud-native bundles. | `ujust cncf` |
| telepresence-oss | Run a local service as if it were inside a remote Kubernetes cluster. | `ujust cncf` |
| tremor-runtime | Event-processing system for unstructured data. | `ujust cncf` |
| wasmedge | Lightweight, high-performance WebAssembly runtime. | `ujust cncf` |
| k0sctl | Bootstrap and manage k0s Kubernetes clusters. | `ujust cncf` |
| k3d | Run lightweight k3s Kubernetes clusters in Docker. | `ujust cncf` |
| ko | Build and deploy Go containers without writing a Dockerfile. | `ujust cncf` |
| kpt | Package, customize, and apply Kubernetes configuration as data. | `ujust cncf` |

Graphical Kubernetes tools:

![Headlamp and OpenLens](appstream://io.kinvolk.Headlamp,appstream://dev.k8slens.OpenLens)

---

## Recommended workflows

- **Local container development** — `ujust devmode` → Docker or Podman Desktop, then `devcontainer up` from your project directory.
- **Remote development containers** — the `ms-vscode-remote.remote-containers` and `ms-vscode-remote.remote-ssh` VS Code extensions are on by default; open a folder over SSH or in a devcontainer.
- **Kubernetes cluster work** — `kind` or `minikube` for local clusters, `kubectl` + `helm` for day-to-day operations, `k9s`, Headlamp, or OpenLens when you want a visual view.
- **Virtualization and local VM work** — `ujust devmode` → virt-manager + QEMU for full VMs, or Lima for lightweight KVM-backed Linux VMs.
- **General shell productivity** — `mise` for per-project runtime versions, `atuin` for searchable shell history, `eza`/`bat`/`fd`/`ripgrep` as everyday replacements for `ls`/`cat`/`find`/`grep`.
