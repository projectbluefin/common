# Developer Experience (DX)

Welcome to the **Developer Experience (DX)** in Project Bluefin! Bluefin provides an out-of-the-box, world-class cloud-native workstation. Rather than layering developer packages on the host system, we leverage **Developer Mode** to turn on developer tools in-place using Homebrew and Flatpaks.

---

## Developer Flatpaks (Exposed from Brewfiles)

Click any app name to open its installation card directly in Bazaar and install it onto your system:

### Core Developer Tools (Exposed from system-dx-flatpaks.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/o/org.gnome.Builder.png" width="48" height="48" style="margin-bottom: 8px;" alt="GNOME Builder">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">GNOME Builder</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Elegant, native GNOME IDE built for GTK4 development.</div>
    <a href="appstream://org.gnome.Builder" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/m/me.iepure.devtoolbox.png" width="48" height="48" style="margin-bottom: 8px;" alt="Dev Toolbox">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Dev Toolbox</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Offline hub containing hashes, formatting, and conversion utilities.</div>
    <a href="appstream://me.iepure.devtoolbox" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/d/de.leopoldluley.Clapgrep.png" width="48" height="48" style="margin-bottom: 8px;" alt="Clapgrep">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Clapgrep</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Highly responsive, visual search UI powered by ripgrep.</div>
    <a href="appstream://de.leopoldluley.Clapgrep" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/i/io.github.getnf.embellish.png" width="48" height="48" style="margin-bottom: 8px;" alt="Embellish">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Embellish</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Install and configure custom Nerd Fonts effortlessly.</div>
    <a href="appstream://io.github.getnf.embellish" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/c/com.github.tuna_os.Tavern.png" width="48" height="48" style="margin-bottom: 8px;" alt="Tavern">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Tavern</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">A lightweight flatpak application manager and companion tool.</div>
    <a href="appstream://com.github.tuna_os.Tavern" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

### Kubernetes & Container Management (Exposed from cncf.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/i/io.podman_desktop.PodmanDesktop.png" width="48" height="48" style="margin-bottom: 8px;" alt="Podman Desktop">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Podman Desktop</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Graphical management tool for containers, pods, and volumes.</div>
    <a href="appstream://io.podman_desktop.PodmanDesktop" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/i/io.kinvolk.Headlamp.png" width="48" height="48" style="margin-bottom: 8px;" alt="Headlamp">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Headlamp</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">A beautiful, highly extensible dashboard for your Kubernetes clusters.</div>
    <a href="appstream://io.kinvolk.Headlamp" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/d/dev.k8slens.OpenLens.png" width="48" height="48" style="margin-bottom: 8px;" alt="OpenLens">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">OpenLens</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Powerful, fully featured desktop IDE for Kubernetes workflows.</div>
    <a href="appstream://dev.k8slens.OpenLens" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

### System Utilities (Exposed from system-flatpaks.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/c/com.github.tchx84.Flatseal.png" width="48" height="48" style="margin-bottom: 8px;" alt="Flatseal">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Flatseal</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Graphical permission editor for sandboxed Flatpak applications.</div>
    <a href="appstream://com.github.tchx84.Flatseal" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/i/io.github.flattool.Warehouse.png" width="48" height="48" style="margin-bottom: 8px;" alt="Warehouse">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Warehouse</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Manage installed Flatpaks, manage user data, and clean up orphan runtimes.</div>
    <a href="appstream://io.github.flattool.Warehouse" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/c/com.mattjakeman.ExtensionManager.png" width="48" height="48" style="margin-bottom: 8px;" alt="Extension Manager">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Extension Manager</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Search, install, and configure GNOME shell extensions.</div>
    <a href="appstream://com.mattjakeman.ExtensionManager" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/i/io.missioncenter.MissionCenter.png" width="48" height="48" style="margin-bottom: 8px;" alt="Mission Center">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Mission Center</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Native GTK system monitor for hardware resource tracking.</div>
    <a href="appstream://io.missioncenter.MissionCenter" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/i/io.github.flattool.Ignition.png" width="48" height="48" style="margin-bottom: 8px;" alt="Ignition">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Ignition</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Setup and configure your Flatpak permissions and configurations.</div>
    <a href="appstream://io.github.flattool.Ignition" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

### AI & Machine Learning (Exposed from ai-tools.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/a/ai.jan.Jan.png" width="48" height="48" style="margin-bottom: 8px;" alt="Jan AI">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Jan AI</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Run open-source LLMs locally on your workstation with a gorgeous native UI.</div>
    <a href="appstream://ai.jan.Jan" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

### GNOME Circle & Desktop Enhancements (Exposed from full-desktop.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/b/be.alexandervanhee.gradia.png" width="48" height="48" style="margin-bottom: 8px;" alt="Gradia">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Gradia</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Dynamic custom styling and CSS gradient compiler for GTK.</div>
    <a href="appstream://be.alexandervanhee.gradia" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/a/app.drey.Damask.png" width="48" height="48" style="margin-bottom: 8px;" alt="Damask">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Damask</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Elegant automatic wallpaper scheduler and rotater.</div>
    <a href="appstream://app.drey.Damask" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/a/app.drey.Elastic.png" width="48" height="48" style="margin-bottom: 8px;" alt="Elastic">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Elastic</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Design spring physics and curves for native GTK4 animations.</div>
    <a href="appstream://app.drey.Elastic" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/a/app.fotema.Fotema.png" width="48" height="48" style="margin-bottom: 8px;" alt="Fotema">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Fotema</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Modern, privacy-first photo gallery and viewer.</div>
    <a href="appstream://app.fotema.Fotema" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/i/io.gitlab.adhami3310.Impression.png" width="48" height="48" style="margin-bottom: 8px;" alt="Impression">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Impression</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Write OCI images and ISOs to USB drives with absolute simplicity.</div>
    <a href="appstream://io.gitlab.adhami3310.Impression" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/i/it.mijorus.smile.png" width="48" height="48" style="margin-bottom: 8px;" alt="Smile">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Smile</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">The best native emoji picker for the GNOME desktop.</div>
    <a href="appstream://it.mijorus.smile" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

---

## Command-Line Utilities (Homebrew)

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

## Product Lore & Design Principles

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

Project Bluefin commits to creating an ergonomic developer environment where the system gets out of the way. All tools are sandboxed, isolated, reproducible, and blazing fast.

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Project Bluefin's **Developer Experience (DX)** is crafted specifically to empower modern engineers with cloud-native primitives, reproducible terminal environments, and robust container workflows, making it the premier workstation operating system.
