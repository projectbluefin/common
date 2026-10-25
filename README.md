# bluefin-common

Shared OCI layer of configuration files for Bluefin images (`bluefin`, `bluefin-lts`) and downstream systems (`dakota`, `utah`, and installation media `iso`).

Agents working in this repo: read [`AGENTS.md`](AGENTS.md) first. It is the
operating contract and this README does not restate it.

## Directory Structure

This repository organizes configuration files into two main directories, these are important:

### `system_files/bluefin/` - Bluefin Specific Configuration
Files specific to Bluefin

- GNOME desktop settings and theming
- Bluefin wallpapers and branding
- Desktop-specific environment variables
- GNOME Initial Setup configuration

### `system_files/shared/` - Shared Configuration
Directly tracked global configuration consumed by all variants. Edit directly here; changes propagate to active downstream systems on build.
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

Default flatpaks are declared as Homebrew Brewfiles in
`system_files/bluefin/usr/share/ublue-os/homebrew/`:

- **`system-flatpaks.Brewfile`** — core flatpaks for all Bluefin variants
- **`system-dx-flatpaks.Brewfile`** — additional flatpaks for DX mode
- **`full-desktop.Brewfile`** — a broad GNOME Circle and community collection

Install the core set:
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

`system_files/shared/usr/share/ublue-os/homebrew/` holds curated CLI and font
bundles: `ai-tools`, `artwork`, `cli`, `cncf`, `experimental-ide`, `fonts`,
`fonts-dev`, `ide`, `k8s-tools`, and `swift`. `preinstall.d/` holds the
bundles applied at first boot (`chairlift`, `system-cli`).

Only two have a `ujust` recipe — `ujust cncf` and `ujust install-system-flatpaks`.
For the rest, point `brew bundle` at the file:

```bash
brew bundle --file=/usr/share/ublue-os/homebrew/k8s-tools.Brewfile
```

## CI / Testing

Per-workflow purpose and ownership:
[`docs/skills/workflow-map.md`](docs/skills/workflow-map.md). What gates a
merge: [`docs/skills/governance.md`](docs/skills/governance.md#how-main-is-protected).

**On every PR** — required status checks gating the merge queue:
- `validate` (`validate.yml`) — `just check`, shellcheck, pre-commit, submodule drift, registry/dconf guards
- `Build and push image (x86_64)` and `Build and push image (aarch64)` (`build.yml`) — builds and scans OCI images; skipped for docs-only PRs

Advisory checks report but do not block: `unit-tests.yml`, `pr-e2e.yml`, `validate-brewfiles.yaml`, `validate-chairlift-config.yaml`, and `scorecard.yml`.

**On merge to main** — full layer validation via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite):
- Runs the [`common` behave suite](https://github.com/projectbluefin/testsuite/tree/main/tests/common) against Bluefin Stable (`bluefin:testing`) and Dakota; LTS is temporarily paused pending bluefin-lts#492
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
