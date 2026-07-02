# Developer Experience (DX)

Welcome to the **Developer Experience (DX)** in Project Bluefin! Bluefin provides an out-of-the-box, world-class cloud-native workstation. Rather than layering developer packages on the host system, we leverage **Developer Mode** to turn on developer tools in-place using Homebrew and Flatpaks.

---

## 🛠️ Developer Flatpaks (Exposed from Brewfiles)

Click any app name to open its installation card directly in Bazaar and install it onto your system:

### Core Developer Tools (Exposed from system-dx-flatpaks.Brewfile)
| App | Description | Action |
| :--- | :--- | :---: |
| 🔨 **GNOME Builder** | Elegant, native GNOME IDE built for GTK4 development. | **[Install](appstream://org.gnome.Builder)** |
| 🧰 **Dev Toolbox** | Offline hub containing hashes, formatting, and conversion utilities. | **[Install](appstream://me.iepure.devtoolbox)** |
| 🔍 **Clapgrep** | Highly responsive, visual search UI powered by ripgrep. | **[Install](appstream://de.leopoldluley.Clapgrep)** |
| 🔠 **Embellish** | Install and configure custom Nerd Fonts effortlessly. | **[Install](appstream://io.github.getnf.embellish)** |
| 🍺 **Tavern** | A lightweight flatpak application manager and companion tool. | **[Install](appstream://com.github.tuna_os.Tavern)** |

### Kubernetes & Container Management (Exposed from cncf.Brewfile)
| App | Description | Action |
| :--- | :--- | :---: |
| 🐳 **Podman Desktop** | Graphical management tool for containers, pods, and volumes. | **[Install](appstream://io.podman_desktop.PodmanDesktop)** |
| ☸️ **Headlamp** | A beautiful, highly extensible dashboard for your Kubernetes clusters. | **[Install](appstream://io.kinvolk.Headlamp)** |
| 🕶️ **OpenLens** | Powerful, fully featured desktop IDE for Kubernetes workflows. | **[Install](appstream://dev.k8slens.OpenLens)** |

### System Utilities (Exposed from system-flatpaks.Brewfile)
| App | Description | Action |
| :--- | :--- | :---: |
| 🛡️ **Flatseal** | Graphical permission editor for sandboxed Flatpak applications. | **[Install](appstream://com.github.tchx84.Flatseal)** |
| 📦 **Warehouse** | Manage installed Flatpaks, manage user data, and clean up orphan runtimes. | **[Install](appstream://io.github.flattool.Warehouse)** |
| ⚙️ **Extension Manager** | Search, install, and configure GNOME shell extensions. | **[Install](appstream://com.mattjakeman.ExtensionManager)** |
| 📊 **Mission Center** | Native GTK system monitor for hardware resource tracking. | **[Install](appstream://io.missioncenter.MissionCenter)** |
| 🚀 **Ignition** | Setup and configure your Flatpak permissions and configurations. | **[Install](appstream://io.github.flattool.Ignition)** |

### AI & Machine Learning (Exposed from ai-tools.Brewfile)
| App | Description | Action |
| :--- | :--- | :---: |
| 🤖 **Jan AI** | Run open-source LLMs locally on your workstation with a gorgeous native UI. | **[Install](appstream://ai.jan.Jan)** |

### GNOME Circle & Desktop Enhancements (Exposed from full-desktop.Brewfile)
| App | Description | Action |
| :--- | :--- | :---: |
| 🌈 **Gradia** | Dynamic custom styling and CSS gradient compiler for GTK. | **[Install](appstream://be.alexandervanhee.gradia)** |
| 🖼️ **Damask** | Elegant automatic wallpaper scheduler and rotater. | **[Install](appstream://app.drey.Damask)** |
| 〰️ **Elastic** | Design spring physics and curves for native GTK4 animations. | **[Install](appstream://app.drey.Elastic)** |
| 📷 **Fotema** | Modern, privacy-first photo gallery and viewer. | **[Install](appstream://app.fotema.Fotema)** |
| 💾 **Impression** | Write OCI images and ISOs to USB drives with absolute simplicity. | **[Install](appstream://io.gitlab.adhami3310.Impression)** |
| 😀 **Smile** | The best native emoji picker for the GNOME desktop. | **[Install](appstream://it.mijorus.smile)** |

---

## 📦 Command-Line Utilities (Homebrew)

Bluefin integrates Homebrew directly on the host to provide lightning-fast shell environments. Click any of the CLI tools to explore their Homebrew Formula page, or run the command below to install them:

```bash
brew install gh just uv neovim k9s lima
```

### Essential CLI Utilities (Exposed from system-cli.Brewfile & cli.Brewfile)
*   [gh](https://formulae.brew.sh/formula/gh) — GitHub's official command-line CLI.
*   [just](https://formulae.brew.sh/formula/just) — Fast and modern project task runner.
*   [uv](https://formulae.brew.sh/formula/uv) — Blazing-fast Python package and workspace manager.
*   [neovim](https://formulae.brew.sh/formula/neovim) — Vim-fork focused on extensibility and usability.
*   [k9s](https://formulae.brew.sh/formula/k9s) — Terminal-based UI for interacting with Kubernetes clusters.
*   [lima](https://formulae.brew.sh/formula/lima) — Linux Virtual Machines with automatic file sharing and port forwarding.

### Modern Shell Tools
*   [atuin](https://formulae.brew.sh/formula/atuin) — Magical shell history database.
*   [bat](https://formulae.brew.sh/formula/bat) — A cat clone with syntax highlighting and Git integration.
*   [chezmoi](https://formulae.brew.sh/formula/chezmoi) — Securely manage dotfiles across multiple machines.
*   [direnv](https://formulae.brew.sh/formula/direnv) — Shell extension to load/unload environment variables per directory.
*   [eza](https://formulae.brew.sh/formula/eza) — A modern, feature-rich replacement for 'ls'.
*   [fd](https://formulae.brew.sh/formula/fd) — Simple, fast, and user-friendly alternative to 'find'.
*   [ripgrep](https://formulae.brew.sh/formula/ripgrep) — High-performance regex search utility.
*   [yq](https://formulae.brew.sh/formula/yq) — Portable command-line YAML/XML/JSON processor.
*   [zoxide](https://formulae.brew.sh/formula/zoxide) — Smarter directory navigation tracker.
*   [mise](https://formulae.brew.sh/formula/mise) — Polyglot development tool, environment variable, and task runner.

### Cloud Native & CNCF Ecosystem (Exposed from cncf.Brewfile)
*   [kubectl](https://formulae.brew.sh/formula/kubernetes-cli) — Command-line tool for controlling Kubernetes clusters.
*   [helm](https://formulae.brew.sh/formula/helm) — Kubernetes package manager.
*   [kind](https://formulae.brew.sh/formula/kind) — Run local Kubernetes clusters using Docker container nodes.
*   [minikube](https://formulae.brew.sh/formula/minikube) — Run a single-node local Kubernetes cluster.
*   [argo](https://formulae.brew.sh/formula/argo) — Workflow engine for Kubernetes.
*   [argocd](https://formulae.brew.sh/formula/argocd) — Declarative continuous delivery engine for Kubernetes.
*   [virtctl](https://formulae.brew.sh/formula/virtctl) — CLI utility for managing KubeVirt virtual machines.
*   [k8sgpt](https://formulae.brew.sh/formula/k8sgpt) — Give your Kubernetes cluster superpowers via AI diagnostics.

---

## 📝 Product Lore & Design Principles

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

Project Bluefin commits to creating an ergonomic developer environment where the system gets out of the way. All tools are sandboxed, isolated, reproducible, and blazing fast.

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Project Bluefin's **Developer Experience (DX)** is crafted specifically to empower modern engineers with cloud-native primitives, reproducible terminal environments, and robust container workflows, making it the premier workstation operating system.
