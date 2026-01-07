# Bluefin-Common Copilot Instructions

This document provides essential information for coding agents working with the bluefin-common repository.

## Repository Overview

**Bluefin-Common** is a shared OCI layer containing common configuration files used across all Bluefin variants (bluefin, bluefin-dx, bluefin-lts).

- **Type**: Minimal OCI container layer (system files only)
- **Purpose**: Centralize shared configuration to reduce duplication across bluefin and bluefin-lts
- **Base**: Built from scratch with COPY directive
- **Languages**: Configuration files (JSON, shell scripts, markdown)
- **Build System**: GitHub Actions with podman/buildah

## Repository Structure

### Root Directory Files
- `Containerfile` - Multi-stage build (scratch → ctx stage with system_files)
- `cosign.pub` - Container signing public key (shared with bluefin/bluefin-lts)
- `README.md` - Basic repository description

### Key Directories
- `system_files/` - All configuration files that get copied into bluefin images
  - `etc/ublue-os/` - System configuration files (bling.json, fastfetch.json, setup.json)
  - `usr/share/ublue-os/` - User-space configurations
    - `firefox-config/` - Firefox default settings
    - `flatpak-overrides/` - Flatpak app overrides
    - `just/` - Just recipe additions
    - `motd/` - Message of the day templates and tips
    - `privileged-setup.hooks.d/` - Privileged setup hooks
    - `system-setup.hooks.d/` - System setup hooks
    - `user-setup.hooks.d/` - User setup hooks

### GitHub Actions
- `.github/workflows/build.yml` - Simple build workflow using podman/buildah

## Build Instructions

### Prerequisites
This repository requires minimal tooling:
- **podman** and **buildah** (usually pre-installed on development systems)
- No Just, no pre-commit, no complex build dependencies

### Build Commands

**Build locally:**
```bash
# Build the container
buildah build -t bluefin-common:latest -f ./Containerfile .

# Inspect the built image
podman images bluefin-common
```

**Test the image:**
```bash
# Copy files from the container to verify structure
podman create --name test bluefin-common:latest
podman cp test:/system_files ./test-output
podman rm test
tree ./test-output
```

### Build Process
1. GitHub Actions triggers on push to main or PR
2. `buildah build` creates image from `Containerfile`
3. Image is pushed to `ghcr.io/projectbluefin/bluefin-common:latest`
4. Bluefin and bluefin-lts reference this image with `COPY --from=ghcr.io/ublue-os/bluefin-common:latest`

## Usage in Downstream Projects

Bluefin and bluefin-lts use this layer in their Containerfiles:

```dockerfile
FROM ghcr.io/ublue-os/bluefin-common:latest AS bluefin-common

# Later in the build:
COPY --from=bluefin-common /system_files /desired/destination
```

## Making Changes

### Modifying Configuration Files

1. **Edit files in `system_files/`** - Maintain the existing directory structure
2. **Test locally** with buildah to ensure no syntax errors
3. **Create PR** - GitHub Actions will build and validate

### Adding New Configuration Files

1. Place files in the appropriate subdirectory under `system_files/`
2. Follow the existing path conventions:
   - System configs: `system_files/etc/ublue-os/`
   - User configs: `system_files/usr/share/ublue-os/`
3. Ensure file permissions are correct (executables for scripts)

### Common Modification Patterns
- **Firefox configs**: Edit `system_files/usr/share/ublue-os/firefox-config/`
- **Setup hooks**: Modify scripts in `system_files/usr/share/ublue-os/*-setup.hooks.d/`
- **System settings**: Update JSON files in `system_files/etc/ublue-os/`
- **Just recipes**: Add/modify `.just` files in `system_files/usr/share/ublue-os/just/`

## Validation

### Manual Validation
```bash
# Check Containerfile syntax
buildah build --dry-run -f ./Containerfile .

# Validate JSON files
find system_files -name "*.json" -exec sh -c 'echo "Checking {}"; cat {} | jq . > /dev/null' \;

# Check shell script syntax
find system_files -name "*.sh" -exec bash -n {} \;
```

### GitHub Actions
The build workflow automatically:
- Builds the container with buildah
- Pushes to GHCR on merge to main
- Validates build succeeds on PRs

## Development Guidelines

### Making Changes
1. **Keep it simple** - This repo contains only configuration files
2. **Maintain structure** - Follow existing directory patterns
3. **Test locally** - Build with buildah before pushing
4. **No complex dependencies** - This is intentionally minimal

### File Editing Best Practices
- **JSON files**: Validate syntax with `jq` before committing
- **Shell scripts**: Check syntax with `bash -n script.sh`
- **Keep files small** - Each file should have a single, clear purpose
- **Document changes** - Update comments in configuration files

## Trust These Instructions

**This repository is intentionally simple.** It contains only:
- Configuration files in `system_files/`
- A minimal Containerfile
- A simple GitHub Actions workflow

There are no complex build systems, no package management, no multi-stage builds beyond the scratch→ctx pattern.

## GitHub Label Structure

This repository follows the CNCF label pattern with `/` separators and color-coded groups.

- When asked to make github labels consistent across bluefin use this set of repositories. Do not touch any other repos:
  - @projectbluefin/common
  - @projectbluefin/distroless
  - @ublue-os/bluefin
  - @ublue-os/bluefin-lts 
  - Ensure that the colors remain consistent

This file is the source of truth for labels in Bluefin.

NEVER touch the issues themselves, only rename the labels.

### Label Categories

**kind/** - Issue types (color: `#a6e3a1` light green)
- `kind/bug` - Something isn't working
- `kind/enhancement` - New feature requests
- `kind/documentation` - Documentation improvements
- `kind/question` - Support questions
- `kind/tech-debt` - Refactoring and maintenance
- `kind/duplicate` - Duplicate issues
- `kind/invalid` - Invalid issues
- `kind/wontfix` - Won't be implemented
- `kind/github-action` - CI/CD automation
- `kind/renovate` - Dependency updates
- `kind/parity` - LTS/Bluefin differences
- `kind/automation` - Workflow automation

**area/** - Configuration areas (Catppuccin Mocha colors by domain)
- Desktop (pink `#f5c2e7`): `area/gnome`, `area/aurora`, `area/bling`
- Development (sky `#89dceb`): `area/dx`, `area/buildstream`, `area/finpilot`
- Package management (peach `#eba0ac`): `area/brew`, `area/just`
- System services (lavender `#b4befe`): `area/services`, `area/policy`
- Infrastructure (teal `#94e2d5`): `area/iso`, `area/upstream`, `area/bluespeed`

**size/** - PR size (color: `#3fb950` dark green)
- `size/XS`, `size/S`, `size/M`, `size/L`, `size/XL`, `size/XXL`

**Other labels** (keep original colors)
- `good first issue` (#7057ff)
- `help wanted` (#008672)
- `lgtm` (#238636)
- `dependencies` (#0366d6)
- `stale` (#dadada)
- `aarch64` (#a8f908)

### Modifying Labels

Use `gh label edit` to rename or recolor labels:

```bash
# Rename and recolor
gh label edit "old-name" --name "new-name" --color "a6e3a1"

# Update only color for kind/ labels
gh label edit "kind/example" --color "a6e3a1"

# Update area/ label with appropriate domain color
gh label edit "area/example" --color "f5c2e7"  # Use domain color
```

When adding new labels, follow the prefix/color pattern above:
- All `kind/` labels use `#a6e3a1` (light green)
- All `size/` labels use `#3fb950` (dark green)
- `area/` labels use domain-specific Catppuccin Mocha colors

## Other Rules

- Use [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) for all commits and PR titles
- Keep changes minimal and surgical
- This layer is used by both bluefin (ublue-os/bluefin) and bluefin-lts (ublue-os/bluefin-lts)
- Changes here affect all downstream Bluefin variants

## Attribution Requirements

AI agents must disclose what tool and model they are using in the "Assisted-by" commit footer:

```text
Assisted-by: [Model Name] via [Tool Name]
```

Example:

```text
Assisted-by: Claude 3.5 Sonnet via GitHub Copilot
```
