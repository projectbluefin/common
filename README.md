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
Files that are shared with [Aurora](https://getaurora.dev) are in [aurorafin-shared](https://github.com/ublue-os/aurorafin-shared), other images can use this as a git submodule or copying or as part of a container build, see below.

This includes:
- `Just` recipes for system management
- Brewfiles for application bundles
- Setup hooks (privileged, system, user)
- Container policies and security settings
- MOTD templates and CLI bling
- Common shell configurations

## Usage in Containerfile

Reference this layer as a build stage and copy the directories you need:

### Copy everything:
```dockerfile
FROM ghcr.io/projectbluefin/common:latest AS bluefin-common

# Copy all system files
COPY --from=bluefin-common /system_files /
```

### Copy only system configuration:

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

## CI / Testing

Changes are validated in three layers:

If you need the per-workflow purpose and ownership map, start with
[`docs/skills/workflow-map.md`](docs/skills/workflow-map.md).

**On every PR**:
- `validate.yml` — `just check`, shellcheck, pre-commit, submodule drift, registry/dconf guards
- `build.yml` — builds the OCI image with `buildah`
- `skill-drift.yml` — warns when implementation changes land without matching skill-doc updates
- `pr-e2e.yml` — advisory composed-image common-suite check against a downstream Bluefin base

**On merge to main** — full layer validation via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite):
- Runs the [`common` behave suite](https://github.com/projectbluefin/testsuite/tree/main/tests/common) against Bluefin LTS, Bluefin Stable, and Dakota
- SSH-mode: behave runs from the GHA runner over SSH into a QEMU VM — no full GNOME session needed, completes in ~15 min
- Validates dconf defaults, locked keys, `ujust`, setup scripts, desktop entries, and shell configuration as they land in the composed images

**Before downstream testing → stable promotions**:
- `promotion-candidate-e2e.yml` runs `smoke,common` against `ghcr.io/projectbluefin/bluefin:{testing,lts-testing}` on Tuesdays, giving `common` a repo-local signal on the exact candidate tags that feed promotion

## Building Locally

```bash
just build
```

## Contributor Metrics

![Alt](https://repobeats.axiom.co/api/embed/45dffc43196101fdeb340b462af3f7babe39eee3.svg "Repobeats analytics image")
