# bluefin-common

Shared OCI layer containing common configuration files used across all Bluefin variants (bluefin, bluefin-dx, bluefin-lts).

## Directory Structure

This repository organizes configuration files into two main directories, these are important:

### `system_files/bluefin/` - Bluefin Specific Configuration
Files specific to Bluefin

- GNOME desktop settings and theming
- Bluefin wallpapers and branding
- Desktop-specific environment variables
- GNOME Initial Setup configuration

### `system_files/shared/` - Shared Configuration
Files that are Bluefin agnostic, so that other images like [Aurora](https://getaurora.dev) can use them.

- `Just` recipes for system management
- Brewfiles for application bundles
- Setup hooks (privileged, system, user)
- Container policies and security settings
- MOTD templates and CLI bling
- Common shell configurations

**When adding new files:** Place in `bluefin/` if desktop/GNOME-specific, otherwise use `shared/`.

## What's Inside

This layer contains two main configuration directories:

### `/etc/ublue-os/` - System Configuration
- Bling - CLI theming settings
- Fastfetch settings - System information display configuration
- Setup configuration - First-boot and system setup parameters

### `/usr/share/ublue-os/` - User-Space Configuration
- Firefox defaults - Pre-configured Firefox settings
- **Flatpak customization** - Multiple levels of flatpak configuration:
  - System-level flatpak overrides in `flatpak-overrides/` (e.g., Bazaar)
  - User-level flatpak overrides in `/etc/skel/.local/share/flatpak/overrides/` (e.g., VSCode, Chrome)
  - System flatpak Brewfiles for default application installation
- Homebrew Brewfiles - Curated application bundles installable via `bbrew`
  - `full-desktop.Brewfile` - Full collection of GNOME Circle and community flatpak applications
  - `system-flatpaks.Brewfile` - Default system-wide flatpaks for all Bluefin variants
  - `system-dx-flatpaks.Brewfile` - Additional flatpaks for DX (Developer Experience) mode
  - Other specialized Brewfiles for fonts, CLI tools, AI tools, etc.
- Just recipes - Additional command recipes for system management
- MOTD templates - Message of the day and tips
- Setup hooks - Scripts for privileged, system, and user setup stages

## Usage in Containerfile

Reference this layer as a build stage and copy the directories you need:

### Copy everything:
```dockerfile
FROM ghcr.io/projectbluefin/common:latest AS bluefin-common

# Copy all system files
COPY --from=bluefin-common /system_files /
```

### Copy only system configuration:

This is what Aurora should use, gives shares the common set of files and keeps the images opinions seperate.

```dockerfile
FROM ghcr.io/projectbluefin/common:latest AS bluefin-common

# Copy only /etc configuration
COPY --from=bluefin-common /system_files/etc /etc
```

### Copy only the image opinion:
```dockerfile
FROM ghcr.io/projectbluefin/common:latest AS bluefin-common

# Copy only /usr/share configuration
COPY --from=bluefin-common /system_files/usr /usr
```

## Flatpak Customization

Bluefin-common provides a comprehensive flatpak customization system with multiple layers:

### System Flatpak Brewfiles

Default flatpaks are now managed via Homebrew Brewfiles, allowing for declarative system-wide installation:

- **`system-flatpaks.Brewfile`** - Core flatpaks installed on all Bluefin variants (37 applications including Firefox, Thunderbird, GNOME Circle apps, and utilities)
- **`system-dx-flatpaks.Brewfile`** - Additional development-focused flatpaks for DX mode (6 applications including Podman Desktop, Builder, and DevToolbox)

These can be installed using:
```bash
ujust install-system-flatpaks
```

### Flatpak Overrides

Two types of flatpak overrides are provided to grant additional permissions to specific applications:

**System-level overrides** (`/usr/share/ublue-os/flatpak-overrides/`):
- `io.github.kolunmi.Bazaar` - Grants access to `host-etc` for system configuration

**User-level overrides** (`/etc/skel/.local/share/flatpak/overrides/`):
- `com.visualstudio.code` - Enables Wayland support and Podman socket access
- `com.google.Chrome` - Grants access to local applications and icons directories

These overrides are automatically applied to new user accounts through the `/etc/skel` template.

## Brewfiles

The `/usr/share/ublue-os/homebrew/` directory contains curated application bundles installable via [bbrew](https://github.com/Valkyrie00/homebrew-bbrew):

- **`system-flatpaks.Brewfile`** - Default system-wide flatpaks for all Bluefin variants
- **`system-dx-flatpaks.Brewfile`** - Additional flatpaks for DX (Developer Experience) mode
- **`full-desktop.Brewfile`** - Comprehensive collection of GNOME Circle and community flatpak applications for a full desktop experience
- **`fonts.Brewfile`** - Additional monospace fonts for development
- **`cli.Brewfile`** - CLI tools and utilities
- **`ai-tools.Brewfile`** - AI and machine learning tools
- **`cncf.Brewfile`** - Cloud Native Computing Foundation tools
- **`k8s-tools.Brewfile`** - Kubernetes tools
- **`ide.Brewfile`** - Integrated development environments
- **`artwork.Brewfile`** - Design and artwork applications

Users can install these bundles using the `ujust bbrew` command, which will prompt them to select a Brewfile.

## Building Locally

```bash
just build
```

## Contributor Metrics

![Alt](https://repobeats.axiom.co/api/embed/45dffc43196101fdeb340b462af3f7babe39eee3.svg "Repobeats analytics image")
