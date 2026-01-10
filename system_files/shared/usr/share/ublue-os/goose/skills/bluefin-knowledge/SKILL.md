---
name: bluefin-knowledge
description: Knowledge base for Bluefin/Universal Blue immutable Linux systems
---

# Bluefin System Knowledge

## What is Bluefin?

Bluefin is an immutable Fedora-based desktop using bootc (formerly rpm-ostree).
Updates are atomic - the system either updates completely or not at all.

- **Website**: https://projectbluefin.io
- **Documentation**: https://docs.projectbluefin.io
- **GitHub**: https://github.com/ublue-os/bluefin

## System Architecture

- **Base image**: Immutable, updated via `bootc upgrade`
- **User apps**: Flatpak (GUI apps), Homebrew (CLI tools), Distrobox (containers)
- **System recipes**: `ujust` commands for common tasks
- **Developer mode**: `ujust devmode` or `ujust toggle-devmode` switches to bluefin-dx image
- **IMPORTANT**: Do NOT use `dnf` directly - it creates layers and breaks updates

## Essential Commands

| Command | Purpose |
|---------|---------|
| `ujust --choose` | Interactive list of all available recipes |
| `ujust --list` | Show all available system recipes |
| `bootc status` | Current deployment and pending updates |
| `bootc upgrade` | Apply system updates |
| `ujust update` | Update everything (system + flatpaks + brew) |
| `ujust device-info` | Gather system info for support |
| `ujust changelogs` | View recent changelogs |

## Complete ujust Recipe Reference

### System Commands
| Recipe | Description |
|--------|-------------|
| `ujust rebase-helper` | Interactive assistant to switch between Bluefin variants |
| `ujust bluefin-cli` | Install CLI tools via Homebrew |
| `ujust toggle-tpm2` | Toggle TPM2-based LUKS unlocking for disk encryption |
| `ujust toggle-user-motd` | Enable/disable MOTD banner on shell startup |
| `ujust clean-system` | Clean Podman/Docker images, Flatpaks, rpm-ostree, Homebrew cache |
| `ujust powerwash` | Factory reset (ERASES ALL DATA - use with extreme caution) |
| `ujust toggle-updates ACTION="prompt"` | Enable/disable auto-updates via systemd timer |
| `ujust secureboot` | Manage secure boot settings |
| `ujust bios` | Access BIOS/UEFI settings |

### App Installation
| Recipe | Description |
|--------|-------------|
| `ujust jetbrains-toolbox` | Install JetBrains Toolbox |
| `ujust install-opentabletdriver` | Install/uninstall OpenTabletDriver |
| `ujust install-gaming-flatpaks` | Install Steam, Heroic, Lutris, ProtonPlus as Flatpaks |
| `ujust bbrew` | Interactive menu to install curated Brewfile bundles |

### AI Tools
| Recipe | Description |
|--------|-------------|
| `ujust bluefin-ai` | Install AI/ML CLI tools (aichat, goose-cli, gemini-cli, llm, ramalama, etc.) |
| `ujust setup-troubleshoot` | Set up AI troubleshooting with linux-mcp-server |
| `ujust troubleshoot` | Start AI troubleshooting session |

### Brewfile Bundles (via `ujust bbrew`)
| Bundle | Contents |
|--------|----------|
| `full-desktop` | GNOME/Flatpak apps for complete desktop |
| `fonts` | Monospace and development fonts |
| `cli` | CLI tools and utilities |
| `ai-tools` | AI/ML tools (aichat, goose, ramalama, whisper-cpp) |
| `cncf` | Cloud Native tools |
| `k8s-tools` | Kubernetes CLI tools |
| `ide` | IDEs/editors (VS Code, JetBrains, Neovim) |
| `artwork` | Design and wallpaper apps |
| `swift` | Swift development environment |

### Custom Recipes
Add custom recipes by creating `/usr/share/ublue-os/just/60-custom.just`

## Image Variants and Rebasing

### Available Variants
| Variant | Description |
|---------|-------------|
| `bluefin` | Standard desktop |
| `bluefin-dx` | Developer tools included |
| `bluefin-nvidia` | NVIDIA drivers included |
| `bluefin-dx-nvidia` | Developer + NVIDIA |
| `bluefin-lts` | Long-term support (CentOS-based) |
| `bluefin-lts-hwe` | LTS with hardware enablement |

### How to Rebase
**Interactive (recommended):**
```bash
ujust rebase-helper
```

**Manual:**
```bash
sudo bootc switch ghcr.io/ublue-os/bluefin:<tag> --enforce-container-sigpolicy
```
Tags: `gts`, `stable`, `latest`, or version/date tags.

For NVIDIA: `ghcr.io/ublue-os/bluefin-nvidia:<tag>`

### Before Rebasing
1. Remove layered packages first: `rpm-ostree reset`
2. Check current image: `sudo bootc status`
3. **NEVER** rebase between CentOS and Fedora Bluefin images

### Get Current Image Name
```bash
jq -r '.["image-name"]' < /usr/share/ublue-os/image-info.json
```

## Troubleshooting: Homebrew Issues

### "brew: command not found"
PATH issue. Fix:
```bash
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```
Or ensure `/etc/profile.d/brew.sh` is sourced in your shell.

### Homebrew Completely Broken
Reset by removing and reinstalling:
```bash
rm -rf /home/linuxbrew/.linuxbrew
rm -rf /etc/.linuxbrew
systemctl start brew-setup.service
```

### "cannot load such file -- sorbet-runtime"
Broken Homebrew installation. Use reset procedure above.

### "Error: invalid option: --no-lock"
Bad brew bundle argument. Workaround:
```bash
brew bundle --file /usr/share/ublue-os/homebrew/bluefin-cli.Brewfile
printf 'source /usr/share/ublue-os/bluefin-cli/bling.sh' >> ~/.bashrc
```

### "Warning: 'bbrew' formula is unreadable"
Tap or formula missing. Remove problematic entry from Brewfile or check tap status.

## Troubleshooting: Flatpak Issues

### Key Facts
- Bluefin uses **system-wide** Flatpaks (not `--user`)
- Manage apps with **Warehouse**
- Manage permissions with **Flatseal**
- System Flatpaks listed in `/etc/ublue-os/system-flatpaks.list`

### Useful Commands
```bash
flatpak list                    # List installed Flatpaks
flatpak permission-show <app>   # Show app permissions
flatpak repair                  # Repair Flatpak installation
```

### Permission Issues
Use Flatseal to grant filesystem/device access. Common permissions needed:
- `~/.local/share` for app data
- `/media` or `/run/media` for external drives
- `host` for full filesystem access (use sparingly)

## Troubleshooting: Distrobox

### Key Facts
- Default ephemeral containers are **deprecated**
- Use `ujust devmode` to enable developer mode first

### Basic Workflow
```bash
distrobox create mycontainer              # Create container
distrobox enter mycontainer               # Enter container
distrobox-export --bin /path/to/exe       # Export app to host
distrobox list                            # List containers
distrobox rm mycontainer                  # Remove container
```

### Device Passthrough
Requires privileged mode (security risk). Only use when necessary.

### For Gaming
Flatpak is preferred. For advanced users, `bazzite-arch` container via Distrobox is an option.

## Troubleshooting: General Issues

### "I can't install packages with dnf/rpm"
Bluefin is immutable. Use instead:
- **GUI apps**: Flatpak or Software Center
- **CLI tools**: `brew install <tool>`
- **Dev environments**: `distrobox create` for mutable containers
- **System packages**: `rpm-ostree install` (sparingly, breaks on rebase)

### System Won't Boot After Update
1. At boot menu (GRUB), select previous deployment
2. Once booted: `sudo bootc rollback`
3. Report issue to Universal Blue

### Check System Health
```bash
sudo bootc status              # Deployment status
journalctl -p err -b           # Errors this boot
systemctl --failed             # Failed services
ujust device-info              # Full system report
```

### Container Issues
```bash
systemctl --user status podman  # Check Podman status
podman system reset             # Reset Podman (removes all containers!)
podman system df                # Check storage usage
```

## Troubleshooting: NVIDIA

### Key Facts
- Bluefin GDX images include NVIDIA drivers and CUDA out of the box
- Secure boot supported with Universal Blue key enrollment
- Always cold boot (full shutdown/restart) after updates to reload drivers

### Common Issues

**Version mismatch after update (GPU workloads/containers broken):**
```bash
ujust rebase-helper   # Update to latest image to sync drivers/libraries
```

**Missing library error (e.g., `libnvidia-tls.so`):**
Temporary workaround (NOT persistent or officially supported):
```bash
sudo bootc usroverlay                    # Make /usr temporarily writable
sudo ln -s /path/to/available.so /path/to/missing.so
```
Better fix: Rebase to latest image or pin to known good image.

**Secure boot enrollment:**
```bash
ujust enroll-secure-boot-key   # Or enroll via UEFI MOK menu at boot
```

**Driver variant switching:**
Rebase to correct image variant:
- `bluefin-nvidia` - Proprietary drivers
- `bluefin-dx-nvidia` - Developer + NVIDIA
- `bluefin-dx-nvidia-open` - Open NVIDIA drivers

### NVIDIA Resources
- Driver discussions: https://github.com/ublue-os/bluefin/issues/2862
- Installation docs: https://docs.projectbluefin.io/installation

## Troubleshooting: Systemd User Services

### Useful Commands
```bash
systemctl --user list-units --type=service   # List user services
systemctl --user status <service>            # Check service status
systemctl --user restart <service>           # Restart a service
systemctl --user enable <service>            # Enable at login
systemctl --user disable <service>           # Disable at login
journalctl --user -u <service>               # View service logs
```

Bluefin does not ship custom user units by default - most are started by applications or the desktop environment.

## Troubleshooting: Podman and Docker

### Key Facts
- **Podman** is the default container runtime (rootless by default)
- **Docker** can be installed but is NOT the default
- Podman uses socket activation and integrates with systemd
- Use Podman unless you need Docker for legacy compatibility

### Common Commands
```bash
podman ps                    # List running containers
podman images                # List images
podman run -it <image>       # Run container interactively
podman system df             # Check storage usage
podman system prune          # Clean unused data
```

### Common Issues
- **Permission errors**: Ensure user is in correct group, avoid running as root
- **Socket issues**: Check `systemctl --user status podman.socket`
- **Full reset**: `podman system reset` (removes ALL containers/images)

## Troubleshooting: Backup and Recovery

### Backup Tools
- **GUI**: Deja Dup, Pika Backup (Flatpaks)
- **CLI**: rclone, restic

### What's Preserved Across Updates
- Home directory (`/home`)
- System configs (`/etc`)

### What's NOT Preserved
- Layered packages (rpm-ostree installs)
- Manual changes to `/usr`

### Recovery Options
```bash
# Rollback to previous deployment
sudo bootc rollback

# Rebase to specific/previous image
ujust rebase-helper

# At boot: Select previous deployment from GRUB menu
```

**Important**: The system image is reproducible - reinstalling Bluefin gets you the same system. But user data in `/home` must be backed up separately!

## Troubleshooting: Layered Packages (rpm-ostree)

### Key Rule
**Avoid layering packages unless absolutely necessary.**

### Why?
- Breaks on rebase between image variants
- Can cause update conflicts
- Unsupported by default in Bluefin

### Alternatives
| Need | Use Instead |
|------|-------------|
| GUI apps | Flatpak |
| CLI tools | Homebrew (`brew install`) |
| Dev environments | Distrobox |
| System packages | Check if ujust recipe exists first |

### If You Must Layer
```bash
rpm-ostree install <package>   # Install (requires reboot)
rpm-ostree uninstall <package> # Remove
rpm-ostree reset               # Remove ALL layered packages
```

### Config Location
`/etc/rpm-ostreed.conf` - Local layering disabled by default

## Hardware: Framework Laptops

Bluefin includes Framework firmware as part of the build process - Framework laptops are supported out of the box.

No special configuration needed.

## Hardware: Secure Boot and TPM

### Secure Boot
Enabled by default with Universal Blue signing key.

**Enroll the key:**
```bash
ujust enroll-secure-boot-key   # Or use UEFI MOK menu at boot
```

**Common issues:**
- Failed key enrollment: Check BIOS settings, ensure Secure Boot is in Setup Mode
- Unsupported boot modes: Use UEFI, not Legacy/CSM

### TPM Unlock for LUKS
```bash
ujust toggle-tpm2   # Enable/disable TPM2-based disk unlock
```

Requires TPM2 chip and LUKS-encrypted disk.

## File Locations

| Path | Purpose |
|------|---------|
| `/etc/ublue-os/` | System-wide Bluefin configs |
| `/usr/share/ublue-os/` | Defaults, overlays, recipes |
| `/usr/share/ublue-os/image-info.json` | Current image metadata |
| `/usr/share/ublue-os/just/` | System ujust recipes |
| `/usr/share/ublue-os/homebrew/` | Brewfile bundles |
| `/etc/ublue-os/system-flatpaks.list` | System Flatpak list |
| `/etc/ublue-os/system-flatpaks-dx.list` | Developer Flatpak list |
| `/etc/rpm-ostreed.conf` | rpm-ostree config (layering disabled) |
| `~/.config/` | User application configs |

### Dotfile Management
Use tools like **chezmoi** for managing user dotfiles across systems.

## Getting Help

1. **Docs**: https://docs.projectbluefin.io
2. **Discord**: https://discord.gg/WEu6BdFEtp
3. **GitHub Issues**: https://github.com/ublue-os/bluefin/issues
4. **System info for support**: `ujust device-info`

## Safety Rules

- NEVER execute commands automatically without user consent
- Present fixes as copyable commands
- Explain what each command does before suggesting it
- For destructive operations (reset, rollback, powerwash), warn explicitly
- When unsure, suggest checking documentation first
- Do NOT use `dnf` directly on Bluefin - it breaks updates
